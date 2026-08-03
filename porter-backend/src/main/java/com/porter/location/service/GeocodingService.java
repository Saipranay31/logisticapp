package com.porter.location.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

/**
 * Service for reverse geocoding - converting coordinates to human-readable addresses.
 * Uses Google Maps Geocoding API with caching.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class GeocodingService {

  private final RestTemplate restTemplate;

  @Value("${google.maps.api.key:}")
  private String googleMapsApiKey;

  // Simple in-memory cache (can be replaced with Redis for production)
  private final Map<String, String> geocodeCache = new HashMap<>();

  /**
   * Reverse geocode coordinates to get human-readable address.
   * Returns format: "123 Main Street, Hyderabad, Telangana 500001"
   * Falls back to coordinate format if API fails: "12.9716, 77.5946"
   */
  public String reverseGeocode(double latitude, double longitude) {
    try {
      String cacheKey = String.format("%.4f,%.4f", latitude, longitude);

      // Check cache first
      if (geocodeCache.containsKey(cacheKey)) {
        log.debug("Geocode cache hit for {}", cacheKey);
        return geocodeCache.get(cacheKey);
      }

      // Try Google Maps API if key is configured
      if (googleMapsApiKey != null && !googleMapsApiKey.isEmpty()) {
        String address = geocodeFromGoogle(latitude, longitude);
        if (address != null) {
          geocodeCache.put(cacheKey, address);
          return address;
        }
      }

      // Fallback: Return formatted coordinates
      String fallbackAddress = String.format("%.4f, %.4f", latitude, longitude);
      geocodeCache.put(cacheKey, fallbackAddress);
      return fallbackAddress;

    } catch (Exception e) {
      log.error("Error geocoding coordinates {},{}: {}", latitude, longitude, e.getMessage());
      return String.format("%.4f, %.4f", latitude, longitude);
    }
  }

  /**
   * Call Google Maps Geocoding API to get address from coordinates.
   * Returns first result's formatted address.
   */
  private String geocodeFromGoogle(double latitude, double longitude) {
    try {
      String url = String.format(
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&key=%s",
          latitude, longitude, googleMapsApiKey
      );

      Map<String, Object> response = restTemplate.getForObject(url, Map.class);

      if (response != null && (boolean) response.getOrDefault("status", "").equals("OK")) {
        java.util.List<?> results = (java.util.List<?>) response.get("results");
        if (results != null && !results.isEmpty()) {
          Map<String, Object> firstResult = (Map<String, Object>) results.get(0);
          String formatted = (String) firstResult.get("formatted_address");
          if (formatted != null) {
            log.debug("Google Geocode result: {} -> {}", latitude + "," + longitude, formatted);
            return formatted;
          }
        }
      }
      return null;
    } catch (Exception e) {
      log.warn("Google Maps API geocoding failed: {}", e.getMessage());
      return null;
    }
  }

  /**
   * Clear the geocoding cache (for testing or manual refresh).
   */
  public void clearCache() {
    geocodeCache.clear();
    log.info("Geocoding cache cleared");
  }

  /**
   * Get cache statistics (for monitoring).
   */
  public Map<String, Object> getCacheStats() {
    return Map.of(
        "cacheSize", geocodeCache.size(),
        "hasGoogleApiKey", googleMapsApiKey != null && !googleMapsApiKey.isEmpty()
    );
  }
}
