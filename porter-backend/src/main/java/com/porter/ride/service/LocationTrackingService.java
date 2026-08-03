package com.porter.ride.service;

import com.porter.common.exception.ResourceNotFoundException;
import com.porter.location.service.LocationService;
import com.porter.ride.entity.Ride;
import com.porter.ride.entity.RideLocationUpdate;
import com.porter.ride.repository.RideLocationUpdateRepository;
import com.porter.ride.repository.RideRepository;
import com.porter.common.enums.RideStatus;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Real-time GPS location tracking during active rides.
 * ✅ PHASE 1: Broadcasts driver location every 5 seconds for smooth real-time tracking
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LocationTrackingService {

  private final RideLocationUpdateRepository locationUpdateRepository;
  private final RideRepository rideRepository;
  private final LocationService locationService;
  private final SimpMessagingTemplate messagingTemplate;

  /**
   * Record driver's location during active ride and broadcast via WebSocket.
   */
  @Transactional
  public void updateRideLocation(UUID rideId, UUID driverId, Double latitude,
      Double longitude, Double speed, Double heading,
      Double accuracy, Double altitude) {
    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    RideLocationUpdate update = RideLocationUpdate.builder()
        .rideId(rideId)
        .driverId(driverId)
        .latitude(latitude)
        .longitude(longitude)
        .speed(speed != null ? speed : 0.0)
        .heading(heading != null ? heading : 0.0)
        .accuracy(accuracy != null ? accuracy : 0.0)
        .altitude(altitude != null ? altitude : 0.0)
        .recordedAt(LocalDateTime.now())
        .build();

    locationUpdateRepository.save(update);

    // Calculate distances
    double distanceToDropoff = locationService.calculateDistance(
        latitude, longitude, ride.getDropLatitude(), ride.getDropLongitude());
    double currentEta = locationService.estimateEta(distanceToDropoff);

    // Broadcast to user via WebSocket
    messagingTemplate.convertAndSend("/topic/ride/" + rideId + "/location",
        Map.of(
            "latitude", latitude,
            "longitude", longitude,
            "speed", speed != null ? speed : 0,
            "heading", heading != null ? heading : 0,
            "distanceToDropoff", Math.round(distanceToDropoff * 100.0) / 100.0,
            "estimatedEta", Math.round(currentEta * 100.0) / 100.0,
            "timestamp", System.currentTimeMillis()));

    log.debug("Location for ride {}: ({},{}), ETA: {}min", rideId, latitude, longitude, currentEta);
  }

  /**
   * ✅ PHASE 1: Scheduled broadcast of all active ride locations every 5 seconds
   * Broadcasts comprehensive location data including driver info for real-time user tracking
   */
  @Scheduled(fixedDelay = 5000)
  @Transactional
  public void broadcastActiveRideLocations() {
    try {
      // Find all IN_PROGRESS rides
      List<Ride> activeRides = rideRepository.findByStatus(RideStatus.IN_PROGRESS);

      if (activeRides.isEmpty()) {
        // No active rides to broadcast
        return;
      }

      log.debug("📡 BROADCASTING {} active rides", activeRides.size());

      for (Ride ride : activeRides) {
        try {
          // Only broadcast if we have driver location
          if (ride.getDriverLatitude() == null || ride.getDriverLongitude() == null) {
            continue;
          }

          // Calculate distance to dropoff and ETA
          double distanceToDropoff = locationService.calculateDistance(
              ride.getDriverLatitude(), ride.getDriverLongitude(),
              ride.getDropLatitude(), ride.getDropLongitude());
          double etaMinutes = locationService.estimateEta(distanceToDropoff);

          // Build comprehensive location message
          Map<String, Object> locationMessage = new HashMap<>();
          locationMessage.put("rideId", ride.getId().toString());
          locationMessage.put("driverLatitude", ride.getDriverLatitude());
          locationMessage.put("driverLongitude", ride.getDriverLongitude());
          locationMessage.put("driverName", "Driver"); // Will be fetched from driver profile if needed
          locationMessage.put("driverPhone", ""); // Will be fetched from driver profile if needed
          locationMessage.put("pickupLatitude", ride.getPickupLatitude());
          locationMessage.put("pickupLongitude", ride.getPickupLongitude());
          locationMessage.put("pickupAddress", ride.getPickupAddress());
          locationMessage.put("dropLatitude", ride.getDropLatitude());
          locationMessage.put("dropLongitude", ride.getDropLongitude());
          locationMessage.put("dropAddress", ride.getDropAddress());
          locationMessage.put("bearing", 0.0); // Will be enhanced with heading data
          locationMessage.put("speed", 0.0);   // Will be enhanced with speed data
          locationMessage.put("accuracy", 0.0); // Will be enhanced from location updates
          locationMessage.put("estimatedEta", (int) etaMinutes);
          locationMessage.put("timestamp", System.currentTimeMillis());

          // Broadcast to user via WebSocket
          messagingTemplate.convertAndSend(
              "/topic/ride/" + ride.getId() + "/location",
              locationMessage
          );

          log.debug("📡 Broadcast location for ride {}: ({}, {}), ETA: {}min",
              ride.getId(), ride.getDriverLatitude(), ride.getDriverLongitude(), etaMinutes);
        } catch (Exception e) {
          log.warn("⚠️ Error broadcasting location for ride {}: {}", ride.getId(), e.getMessage());
        }
      }
    } catch (Exception e) {
      log.error("❌ Error in broadcastActiveRideLocations: {}", e.getMessage(), e);
    }
  }

  /**
   * Fix 4: Called by the WebSocket STOMP handler when a driver sends a location
   * update via /app/driver/location.  Previously that path only wrote to Redis;
   * now it also updates the Ride entity and broadcasts immediately so the user
   * tracking screen gets real-time updates rather than waiting for the 5-second
   * scheduler heartbeat.
   */
  @Transactional
  public void updateRideLocationFromWebSocket(UUID driverId, double latitude, double longitude) {
    try {
      List<Ride> activeRides = rideRepository.findByDriverIdAndStatusIn(driverId, List.of(
          RideStatus.ASSIGNED, RideStatus.ARRIVED, RideStatus.IN_PROGRESS));

      if (activeRides.isEmpty()) {
        return; // driver is not on an active ride — Redis-only update is enough
      }

      for (Ride ride : activeRides) {
        // Persist latest location on the Ride row (read by scheduler + mapToDto fallback)
        ride.setDriverLatitude(latitude);
        ride.setDriverLongitude(longitude);
        rideRepository.save(ride);

        // Calculate real-time ETA
        double distToDropoff = locationService.calculateDistance(
            latitude, longitude, ride.getDropLatitude(), ride.getDropLongitude());
        double etaMinutes = locationService.estimateEta(distToDropoff);

        // Broadcast immediately — no 5-second delay
        messagingTemplate.convertAndSend(
            "/topic/ride/" + ride.getId() + "/location",
            Map.of(
                "rideId",            ride.getId().toString(),
                "latitude",          latitude,
                "longitude",         longitude,
                "distanceToDropoff", Math.round(distToDropoff * 100.0) / 100.0,
                "estimatedEta",      Math.round(etaMinutes * 100.0) / 100.0,
                "timestamp",         System.currentTimeMillis()));

        log.debug("📡 WS location → ride {}: ({}, {}), ETA {}min",
            ride.getId(), latitude, longitude, (int) etaMinutes);
      }
    } catch (Exception e) {
      log.error("❌ updateRideLocationFromWebSocket error (driver {}): {}", driverId, e.getMessage());
    }
  }

  /**
   * Get driver's current location for a ride.
   */
  public Map<String, Object> getCurrentLocation(UUID rideId) {
    RideLocationUpdate latest = locationUpdateRepository
        .findFirstByRideIdOrderByRecordedAtDesc(rideId).orElse(null);

    if (latest == null) {
      return Map.of("available", false);
    }

    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    double distanceToDropoff = locationService.calculateDistance(
        latest.getLatitude(), latest.getLongitude(),
        ride.getDropLatitude(), ride.getDropLongitude());
    double eta = locationService.estimateEta(distanceToDropoff);

    Map<String, Object> result = new HashMap<>();
    result.put("available", true);
    result.put("latitude", latest.getLatitude());
    result.put("longitude", latest.getLongitude());
    result.put("speed", latest.getSpeed());
    result.put("heading", latest.getHeading());
    result.put("distanceToDropoff", Math.round(distanceToDropoff * 100.0) / 100.0);
    result.put("estimatedEta", Math.round(eta * 100.0) / 100.0);
    result.put("lastUpdated", latest.getRecordedAt());
    result.put("secondsAgo", ChronoUnit.SECONDS.between(latest.getRecordedAt(), LocalDateTime.now()));
    return result;
  }

  /**
   * Get route waypoints for a ride (for map polyline).
   */
  public List<Map<String, Object>> getRideWaypoints(UUID rideId) {
    return locationUpdateRepository.findByRideIdOrderByRecordedAtAsc(rideId)
        .stream()
        .map(loc -> {
          Map<String, Object> m = new HashMap<>();
          m.put("latitude", loc.getLatitude());
          m.put("longitude", loc.getLongitude());
          m.put("speed", loc.getSpeed());
          m.put("timestamp", loc.getRecordedAt());
          return m;
        })
        .collect(Collectors.toList());
  }

  /**
   * Calculate actual distance traveled using recorded waypoints.
   */
  public double calculateActualDistance(UUID rideId) {
    List<RideLocationUpdate> locations = locationUpdateRepository
        .findByRideIdOrderByRecordedAtAsc(rideId);

    if (locations.size() < 2)
      return 0.0;

    double total = 0.0;
    for (int i = 0; i < locations.size() - 1; i++) {
      RideLocationUpdate cur = locations.get(i);
      RideLocationUpdate nxt = locations.get(i + 1);
      total += locationService.calculateDistance(
          cur.getLatitude(), cur.getLongitude(),
          nxt.getLatitude(), nxt.getLongitude());
    }
    return Math.round(total * 100.0) / 100.0;
  }
}
