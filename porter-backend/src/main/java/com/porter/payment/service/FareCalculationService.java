package com.porter.payment.service;

import com.porter.common.enums.RideStatus;
import com.porter.common.enums.VehicleType;
import com.porter.location.service.LocationService;
import com.porter.ride.entity.Ride;
import com.porter.ride.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * ✅ PHASE 2: Real-time dynamic fare calculation during trip
 * Calculates actual fare based on real distance traveled and time elapsed
 * OPTIMIZED: Only broadcasts to rides with active subscribers
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FareCalculationService {

  private final RideRepository rideRepository;
  private final LocationService locationService;
  private final SimpMessagingTemplate messagingTemplate;

  // Track active subscribers per ride to avoid wasteful broadcasts
  private final Map<String, Integer> rideSubscriberCount = new ConcurrentHashMap<>();

  @Value("${porter.fare.base-fare:50.0}")
  private double baseFare;

  @Value("${porter.fare.per-km-rate:12.0}")
  private double perKmRate;

  @Value("${porter.fare.per-min-rate:2.0}")
  private double perMinRate;

  /**
   * Register a subscriber for a ride's fare updates
   * Called when user/driver subscribes to WebSocket topic
   */
  public void addSubscriber(String rideId) {
    rideSubscriberCount.merge(rideId, 1, Integer::sum);
    log.info("✅ SUBSCRIBER ADDED: ride={}, subscribers={}", rideId, rideSubscriberCount.get(rideId));
  }

  /**
   * Unregister a subscriber for a ride's fare updates
   * Called when user/driver disconnects from WebSocket topic
   */
  public void removeSubscriber(String rideId) {
    rideSubscriberCount.compute(rideId, (key, count) -> {
      if (count == null || count <= 1) {
        log.info("✅ LAST SUBSCRIBER REMOVED: ride={}", rideId);
        return null;
      }
      int newCount = count - 1;
      log.info("✅ SUBSCRIBER REMOVED: ride={}, remaining={}", rideId, newCount);
      return newCount;
    });
  }

  /**
   * Get current subscriber count for a ride
   */
  public int getSubscriberCount(String rideId) {
    return rideSubscriberCount.getOrDefault(rideId, 0);
  }

  /**
   * Calculate current actual fare for a ride (includes vehicle multiplier)
   */
  public double calculateActualFare(Ride ride) {
    // Only calculate for IN_PROGRESS rides
    if (ride.getStatus() != RideStatus.IN_PROGRESS) {
      return ride.getEstimatedFare(); // Return estimated fare for other statuses
    }

    // Validate we have trip start data
    if (ride.getTripStartLatitude() == null || ride.getTripStartLongitude() == null ||
        ride.getTripStartTime() == null || ride.getDriverLatitude() == null ||
        ride.getDriverLongitude() == null) {
      log.warn("❌ Incomplete trip data for ride {}", ride.getId());
      return ride.getActualFare() != null ? ride.getActualFare() : ride.getEstimatedFare();
    }

    // ✅ FIX: Apply vehicle multiplier (consistent with client-side calculation)
    double vehicleMultiplier = 1.0;
    if (ride.getVehicleType() != null) {
      if (ride.getVehicleType().equals(VehicleType.BIKE)) {
        vehicleMultiplier = 0.8;
      } else if (ride.getVehicleType().equals(VehicleType.AUTO)) {
        vehicleMultiplier = 1.0;
      } else if (ride.getVehicleType().equals(VehicleType.MINI_TRUCK)) {
        vehicleMultiplier = 1.5;
      } else if (ride.getVehicleType().equals(VehicleType.TRUCK)) {
        vehicleMultiplier = 2.0;
      }
    }

    // Distance from trip START to current driver location
    double distanceTraveled = locationService.calculateDistance(
      ride.getTripStartLatitude(), ride.getTripStartLongitude(),
      ride.getDriverLatitude(), ride.getDriverLongitude()
    );

    // Time elapsed since trip start
    Duration elapsed = Duration.between(ride.getTripStartTime(), LocalDateTime.now());
    double minutesElapsed = elapsed.toSeconds() / 60.0;

    // Calculate actual fare with vehicle multiplier applied to all components
    double baseFareComponent = baseFare * vehicleMultiplier;
    double distanceComponent = distanceTraveled * perKmRate * vehicleMultiplier;
    double timeComponent = minutesElapsed * perMinRate * vehicleMultiplier;
    double actualFare = baseFareComponent + distanceComponent + timeComponent;

    // Round to 2 decimal places
    actualFare = Math.round(actualFare * 100.0) / 100.0;

    log.info("💰 FARE CALC: ride={}, vehicle={}, multiplier={}, distance={:.2f}km, time={:.1f}min, fare=₹{} (base={}, distance={}, time={})",
      ride.getId(), ride.getVehicleType(), vehicleMultiplier, distanceTraveled, minutesElapsed, actualFare,
      baseFareComponent, distanceComponent, timeComponent);

    return actualFare;
  }

  /**
   * Update ongoing ride fares every 5 seconds (PHASE 6: Real-time streaming)
   * OPTIMIZED: Only broadcasts to rides with active subscribers
   * Broadcasts fare breakdown with all components for real-time UI updates
   */
  @Scheduled(fixedDelay = 5000)  // Every 5 seconds for real-time updates
  @Transactional
  public void updateOngoingRideFares() {
    try {
      // Get rides that have active subscribers
      Set<String> subscribedRideIds = new HashSet<>(rideSubscriberCount.keySet());

      if (subscribedRideIds.isEmpty()) {
        log.debug("⏭️ SKIP BROADCAST: No active subscribers");
        return;
      }

      // Find all IN_PROGRESS rides that have subscribers
      List<Ride> inProgressRides = rideRepository.findByStatus(RideStatus.IN_PROGRESS);
      List<Ride> ridesToBroadcast = inProgressRides.stream()
        .filter(ride -> subscribedRideIds.contains(ride.getId().toString()))
        .toList();

      if (ridesToBroadcast.isEmpty()) {
        log.debug("⏭️ SKIP BROADCAST: No IN_PROGRESS rides with subscribers");
        return;
      }

      log.info("📡 BROADCASTING {} rides to {} total subscribers",
        ridesToBroadcast.size(), subscribedRideIds.size());

      for (Ride ride : ridesToBroadcast) {
        // Calculate new fare
        double newFare = calculateActualFare(ride);
        ride.setActualFare(newFare);
        rideRepository.save(ride);

        // Distance and time for display
        double distanceTraveled = ride.getTripStartLatitude() != null ?
          locationService.calculateDistance(
            ride.getTripStartLatitude(), ride.getTripStartLongitude(),
            ride.getDriverLatitude(), ride.getDriverLongitude()
          ) : 0;

        // Calculate duration
        long secondsElapsed = 0;
        if (ride.getTripStartTime() != null) {
          secondsElapsed = Duration.between(
            ride.getTripStartTime(), LocalDateTime.now()
          ).toSeconds();
        }
        double minutesElapsed = secondsElapsed / 60.0;

        // ✅ PHASE 6: Calculate fare components for breakdown display
        double vehicleMultiplier = 1.0;
        if (ride.getVehicleType() != null) {
          if (ride.getVehicleType().equals(VehicleType.BIKE)) {
            vehicleMultiplier = 0.8;
          } else if (ride.getVehicleType().equals(VehicleType.AUTO)) {
            vehicleMultiplier = 1.0;
          } else if (ride.getVehicleType().equals(VehicleType.MINI_TRUCK)) {
            vehicleMultiplier = 1.5;
          } else if (ride.getVehicleType().equals(VehicleType.TRUCK)) {
            vehicleMultiplier = 2.0;
          }
        }
        double baseFareComponent = baseFare * vehicleMultiplier;
        double distanceComponent = distanceTraveled * perKmRate * vehicleMultiplier;
        double timeComponent = minutesElapsed * perMinRate * vehicleMultiplier;

        // Broadcast to both user and driver via WebSocket with full breakdown
        Map<String, Object> fareUpdate = new HashMap<>();
        fareUpdate.put("rideId", ride.getId().toString());
        fareUpdate.put("actualFare", Math.round(newFare * 100.0) / 100.0);
        fareUpdate.put("baseFare", Math.round(baseFareComponent * 100.0) / 100.0);
        fareUpdate.put("distanceTraveled", Math.round(distanceTraveled * 100.0) / 100.0);
        fareUpdate.put("distanceCharge", Math.round(distanceComponent * 100.0) / 100.0);
        fareUpdate.put("timeElapsed", (int) secondsElapsed);
        fareUpdate.put("timeCharge", Math.round(timeComponent * 100.0) / 100.0);
        fareUpdate.put("vehicleMultiplier", vehicleMultiplier);
        fareUpdate.put("timestamp", System.currentTimeMillis());

        // Topic: /topic/ride/{rideId}/fare
        messagingTemplate.convertAndSend(
          "/topic/ride/" + ride.getId() + "/fare",
          fareUpdate
        );

        log.info("📡 BROADCAST FARE (5s): ride={}, subscribers={}, fare=₹{} (base={}, dist={}, time={})",
          ride.getId(), getSubscriberCount(ride.getId().toString()), newFare,
          baseFareComponent, distanceComponent, timeComponent);
      }
    } catch (Exception e) {
      log.error("❌ Error updating fares: {}", e.getMessage(), e);
    }
  }
}
