package com.porter.location.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.geo.*;
import org.springframework.data.redis.connection.RedisGeoCommands;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Location service using Redis GEO for driver location tracking and nearby
 * search.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LocationService {

  private static final String DRIVER_LOCATIONS_KEY = "driver:locations";
  private static final String DRIVER_LOCATION_METADATA_PREFIX = "driver:location:metadata:";
  private static final long LOCATION_TTL_SECONDS = 120; // 2 minutes - auto-cleanup stale locations
  private final StringRedisTemplate redisTemplate;

  /**
   * Update driver's location in Redis GEO set with TTL metadata.
   * Location is stored in GEO set + metadata stored with TTL for auto-cleanup.
   */
  public void updateDriverLocation(String driverId, double latitude, double longitude) {
    try {
      // Store in GEO set for radius queries
      redisTemplate.opsForGeo().add(DRIVER_LOCATIONS_KEY,
          new Point(longitude, latitude), driverId);

      // Store metadata with TTL - auto-removes if driver goes offline ungracefully
      String metadataKey = DRIVER_LOCATION_METADATA_PREFIX + driverId;
      String metadata = latitude + "," + longitude + "," + System.currentTimeMillis();
      redisTemplate.opsForValue().set(metadataKey, metadata, Duration.ofSeconds(LOCATION_TTL_SECONDS));

      log.info("✅ REDIS UPDATE: Driver {} location saved: ({}, {}), TTL: {}s",
          driverId, latitude, longitude, LOCATION_TTL_SECONDS);
    } catch (Exception e) {
      log.error("❌ REDIS ERROR: Failed to update driver {} location: {}", driverId, e.getMessage(), e);
    }
  }

  /**
   * Remove driver's location from Redis (when going offline).
   * Also removes metadata to prevent stale data.
   */
  public void removeDriverLocation(String driverId) {
    redisTemplate.opsForGeo().remove(DRIVER_LOCATIONS_KEY, driverId);
    String metadataKey = DRIVER_LOCATION_METADATA_PREFIX + driverId;
    redisTemplate.delete(metadataKey);
    log.debug("Removed location and metadata for driver {}", driverId);
  }

  /**
   * Find nearby drivers within a given radius.
   * Only returns drivers with valid metadata (i.e., actively online).
   * Returns list of driver IDs sorted by distance.
   */
  public List<String> findNearbyDrivers(double latitude, double longitude, double radiusKm) {
    log.info("🔍 SEARCHING: Looking for drivers within {}km of ({}, {})", radiusKm, latitude, longitude);

    GeoResults<RedisGeoCommands.GeoLocation<String>> results = redisTemplate.opsForGeo().radius(
        DRIVER_LOCATIONS_KEY,
        new Circle(new Point(longitude, latitude), new Distance(radiusKm, Metrics.KILOMETERS)),
        RedisGeoCommands.GeoRadiusCommandArgs.newGeoRadiusArgs()
            .includeDistance()
            .sortAscending()
            .limit(20));

    if (results == null) {
      log.warn("⚠️ NO RESULTS: Redis geo radius returned null");
      return Collections.emptyList();
    }

    log.info("📍 FOUND {} drivers in Redis GEO set", results.getContent().size());

    // Filter only drivers with valid metadata (TTL not expired = actively online)
    List<String> onlineDrivers = results.getContent().stream()
        .map(r -> r.getContent().getName())
        .filter(driverId -> {
          String metadataKey = DRIVER_LOCATION_METADATA_PREFIX + driverId;
          Boolean exists = redisTemplate.hasKey(metadataKey);
          return exists != null && exists;
        })
        .collect(Collectors.toList());

    log.info("✅ ONLINE DRIVERS: {} drivers are actively online out of {}", onlineDrivers.size(), results.getContent().size());
    return onlineDrivers;
  }

  /**
   * Calculate distance between two points using Haversine formula.
   */
  public double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final double R = 6371; // Earth's radius in km
    double dLat = Math.toRadians(lat2 - lat1);
    double dLng = Math.toRadians(lng2 - lng1);
    double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Estimate ETA in minutes based on distance (average speed: 30 km/h in city).
   */
  public double estimateEta(double distanceKm) {
    double avgSpeedKmh = 30.0;
    return (distanceKm / avgSpeedKmh) * 60;
  }

  /**
   * Get driver's current location from Redis GEO.
   * Only returns location if driver metadata exists (actively online).
   */
  public Map<String, Double> getDriverLocation(String driverId) {
    // Check if driver metadata exists (TTL not expired)
    String metadataKey = DRIVER_LOCATION_METADATA_PREFIX + driverId;
    Boolean metadataExists = redisTemplate.hasKey(metadataKey);
    if (metadataExists == null || !metadataExists) {
      log.debug("Driver {} is offline or metadata expired", driverId);
      return Map.of();
    }

    List<org.springframework.data.geo.Point> positions = redisTemplate.opsForGeo()
        .position(DRIVER_LOCATIONS_KEY, driverId);
    if (positions == null || positions.isEmpty() || positions.get(0) == null) {
      return Map.of();
    }
    org.springframework.data.geo.Point point = positions.get(0);
    Map<String, Double> loc = new HashMap<>();
    loc.put("latitude", point.getY());
    loc.put("longitude", point.getX());
    return loc;
  }
}
