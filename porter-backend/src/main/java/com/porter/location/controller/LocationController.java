package com.porter.location.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.common.exception.ResourceNotFoundException;
import com.porter.driver.dto.DriverProfileDto;
import com.porter.driver.service.DriverService;
import com.porter.location.service.LocationService;
import com.porter.location.service.GeocodingService;
import com.porter.ride.entity.Ride;
import com.porter.ride.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/location")
@RequiredArgsConstructor
@Slf4j
public class LocationController {

  private final LocationService locationService;
  private final RideRepository rideRepository;
  private final DriverService driverService;
  private final GeocodingService geocodingService;
  private final SimpMessagingTemplate messagingTemplate;

  /**
   * Update driver location (called periodically by driver app).
   * ✅ PHASE 1: Also broadcast to WebSocket for real-time user tracking
   * ✅ PHASE 6: Include address in location broadcast
   */
  @PostMapping("/update")
  public ResponseEntity<ApiResponse<Void>> updateLocation(
      Authentication auth,
      @RequestParam double latitude,
      @RequestParam double longitude) {
    UUID driverId = UUID.fromString(auth.getName());
    log.info("📍 LOCATION UPDATE: Driver {} sending location: ({}, {})", driverId, latitude, longitude);
    try {
      locationService.updateDriverLocation(driverId.toString(), latitude, longitude);
      log.info("✅ LOCATION SAVED: Driver {} location persisted to Redis", driverId);

      // ✅ Update active rides with driver's current location
      List<Ride> activeRides = rideRepository.findByDriverIdAndStatusIn(driverId,
        List.of(
          com.porter.common.enums.RideStatus.ASSIGNED,
          com.porter.common.enums.RideStatus.ARRIVED,
          com.porter.common.enums.RideStatus.IN_PROGRESS
        ));

      for (Ride ride : activeRides) {
        // 🔴 FIX: Use try-catch to handle concurrent updates gracefully
        // If two location requests arrive simultaneously, only one needs to succeed
        try {
          ride.setDriverLatitude(latitude);
          ride.setDriverLongitude(longitude);
          rideRepository.save(ride);
        } catch (Exception e) {
          // Optimistic lock failure is OK — another thread already updated
          log.debug("⚠️ Skipping concurrent ride update for ride {} (another thread won)", ride.getId());
        }

        // ✅ Geocode address for display
        String address = "Driver at " + latitude + ", " + longitude;
        try {
          address = geocodingService.reverseGeocode(latitude, longitude);
          log.info("✅ Geocoded location: {}", address);
        } catch (Exception e) {
          log.warn("⚠️ Geocoding failed, using coordinate format: {}", e.getMessage());
        }

        // Broadcast location update to user via WebSocket
        Map<String, Object> locationUpdate = Map.of(
          "latitude", latitude,
          "longitude", longitude,
          "address", address,
          "timestamp", System.currentTimeMillis(),
          "accuracy", 0
        );
        messagingTemplate.convertAndSend(
          "/topic/ride/" + ride.getId() + "/location",
          locationUpdate
        );

        log.info("📡 BROADCAST: Sent location for ride {} to user {}: {}", ride.getId(), ride.getUserId(), address);
      }

      return ResponseEntity.ok(ApiResponse.success("Location updated", null));
    } catch (Exception e) {
      log.error("❌ LOCATION ERROR: Failed to save driver {} location: {}", driverId, e.getMessage(), e);
      return ResponseEntity.status(500).body(ApiResponse.error("Failed to update location: " + e.getMessage()));
    }
  }

  /**
   * Calculate distance and ETA between two points.
   */
  @GetMapping("/distance")
  public ResponseEntity<ApiResponse<Map<String, Double>>> getDistance(
      @RequestParam double pickupLat, @RequestParam double pickupLng,
      @RequestParam double dropLat, @RequestParam double dropLng) {
    double distance = locationService.calculateDistance(pickupLat, pickupLng, dropLat, dropLng);
    double eta = locationService.estimateEta(distance);
    return ResponseEntity.ok(ApiResponse.success(Map.of(
        "distanceKm", Math.round(distance * 100.0) / 100.0,
        "etaMinutes", Math.round(eta * 100.0) / 100.0)));
  }

  /**
   * Get current driver location for a ride with full details (PHASE 1 endpoint).
   * Returns comprehensive location data including driver info for real-time tracking.
   */
  @GetMapping("/current/{rideId}")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getCurrentLocation(@PathVariable UUID rideId) {
    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    if (ride.getDriverId() == null) {
      return ResponseEntity.ok(ApiResponse.success("No driver assigned yet", null));
    }

    try {
      // Get driver profile for name and phone
      DriverProfileDto driverProfile = driverService.getDriverProfile(ride.getDriverId());

      Map<String, Object> location = new HashMap<>();
      location.put("rideId", rideId.toString());
      location.put("driverLatitude", ride.getDriverLatitude() != null ? ride.getDriverLatitude() : 0.0);
      location.put("driverLongitude", ride.getDriverLongitude() != null ? ride.getDriverLongitude() : 0.0);
      location.put("driverName", driverProfile.getFullName());
      location.put("driverPhone", driverProfile.getPhone());
      location.put("pickupLatitude", ride.getPickupLatitude());
      location.put("pickupLongitude", ride.getPickupLongitude());
      location.put("pickupAddress", ride.getPickupAddress());
      location.put("dropLatitude", ride.getDropLatitude());
      location.put("dropLongitude", ride.getDropLongitude());
      location.put("dropAddress", ride.getDropAddress());
      location.put("bearing", 0.0); // Will be updated via LocationTrackingService
      location.put("speed", 0.0);   // Will be updated via LocationTrackingService
      location.put("accuracy", 0.0); // Will be updated via LocationTrackingService
      location.put("timestamp", System.currentTimeMillis());

      // Estimate ETA to drop
      double etaMinutes = locationService.estimateEta(
          locationService.calculateDistance(
              ride.getDriverLatitude() != null ? ride.getDriverLatitude() : ride.getPickupLatitude(),
              ride.getDriverLongitude() != null ? ride.getDriverLongitude() : ride.getPickupLongitude(),
              ride.getDropLatitude(),
              ride.getDropLongitude()
          )
      );
      location.put("estimatedEta", (int) etaMinutes);

      return ResponseEntity.ok(ApiResponse.success(location));
    } catch (Exception e) {
      log.error("Error fetching current location for ride {}: {}", rideId, e.getMessage());
      return ResponseEntity.status(500).body(ApiResponse.error("Failed to fetch location: " + e.getMessage()));
    }
  }

  /**
   * Get driver location for a ride (user tracking) - deprecated, use /current/{rideId}
   */
  @GetMapping("/driver/{rideId}")
  public ResponseEntity<ApiResponse<Map<String, Double>>> getDriverLocation(@PathVariable UUID rideId) {
    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
    if (ride.getDriverId() == null) {
      return ResponseEntity.ok(ApiResponse.success("No driver assigned yet", null));
    }
    Map<String, Double> location = locationService.getDriverLocation(ride.getDriverId().toString());
    return ResponseEntity.ok(ApiResponse.success(location));
  }

  /**
   * 🔴 PHASE 2C: Find nearby drivers for user driver discovery.
   * Returns list of available drivers with location, rating, distance, and ETA.
   */
  @GetMapping("/nearby-drivers")
  public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getNearbyDrivers(
      @RequestParam double latitude,
      @RequestParam double longitude,
      @RequestParam(defaultValue = "BIKE") String vehicleType,
      @RequestParam(defaultValue = "5.0") double radius) {

    // Find drivers within radius
    List<String> nearbyDriverIds = locationService.findNearbyDrivers(latitude, longitude, radius);

    // Convert to driver details with distance and ETA
    List<Map<String, Object>> drivers = new ArrayList<>();

    for (String driverId : nearbyDriverIds) {
      try {
        UUID driverUuid = UUID.fromString(driverId);
        DriverProfileDto profile = driverService.getDriverProfile(driverUuid);

        // Get driver location
        Map<String, Double> driverLocation = locationService.getDriverLocation(driverId);
        if (driverLocation.isEmpty()) continue; // Skip if no location

        double driverLat = driverLocation.get("latitude");
        double driverLng = driverLocation.get("longitude");

        // Calculate distance from user to driver
        double distance = locationService.calculateDistance(latitude, longitude, driverLat, driverLng);
        double eta = locationService.estimateEta(distance);

        // Build driver info
        Map<String, Object> driverInfo = new HashMap<>();
        driverInfo.put("id", profile.getUserId());
        driverInfo.put("name", profile.getFullName());
        driverInfo.put("rating", profile.getRating());
        driverInfo.put("totalRides", profile.getTotalRides());
        driverInfo.put("vehicleType", profile.getVehicleType());
        driverInfo.put("vehicleNumber", profile.getVehicleNumber());
        driverInfo.put("latitude", driverLat);
        driverInfo.put("longitude", driverLng);
        driverInfo.put("distance", Math.round(distance * 100.0) / 100.0); // Distance in km
        driverInfo.put("eta", Math.round(eta * 100.0) / 100.0); // ETA in minutes

        drivers.add(driverInfo);
      } catch (Exception e) {
        // Skip drivers with errors
        continue;
      }
    }

    // Sort by rating (highest first) by default
    drivers.sort((a, b) -> Double.compare((double) b.get("rating"), (double) a.get("rating")));

    return ResponseEntity.ok(ApiResponse.success(drivers));
  }
}
