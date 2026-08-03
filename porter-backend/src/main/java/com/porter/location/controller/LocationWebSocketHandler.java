package com.porter.location.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.porter.location.service.LocationService;
import com.porter.ride.service.LocationTrackingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;

import java.util.UUID;

/**
 * WebSocket STOMP handler for driver location updates.
 *
 * Fix 4: In addition to writing the location to Redis (for driver discovery),
 * we now also update the active Ride entity in the DB and immediately broadcast
 * the new position to the user's tracking screen.  Previously the user only
 * received updates from the 5-second scheduler heartbeat; they now arrive in
 * real-time as the driver sends each GPS ping.
 */
@Controller
@RequiredArgsConstructor
@Slf4j
public class LocationWebSocketHandler {

  private final LocationService locationService;
  private final LocationTrackingService locationTrackingService;
  private final ObjectMapper objectMapper;

  @MessageMapping("/driver/location")
  public void receiveDriverLocation(@Payload String payload, Authentication auth) {
    try {
      var locationMsg = objectMapper.readValue(payload, java.util.Map.class);
      double latitude  = ((Number) locationMsg.get("latitude")).doubleValue();
      double longitude = ((Number) locationMsg.get("longitude")).doubleValue();

      // Resolve driverId from payload first (STOMP auth can be null on some clients)
      String driverIdStr = null;
      Object driverIdObj = locationMsg.get("driverId");
      if (driverIdObj != null) {
        driverIdStr = driverIdObj.toString();
      } else if (auth != null) {
        driverIdStr = auth.getName();
      }

      if (driverIdStr == null || driverIdStr.isEmpty()) {
        log.warn("⚠️ WebSocket location received but no driverId found");
        return;
      }

      UUID driverId = UUID.fromString(driverIdStr);
      log.debug("📡 WS location: driver={} ({}, {})", driverId, latitude, longitude);

      // 1. Write to Redis GEO — used for driver discovery during matching
      locationService.updateDriverLocation(driverId.toString(), latitude, longitude);

      // 2. Fix 4: Update active Ride entity + broadcast to user tracking screen
      locationTrackingService.updateRideLocationFromWebSocket(driverId, latitude, longitude);

    } catch (Exception e) {
      log.error("❌ WebSocket location error: {}", e.getMessage(), e);
    }
  }
}
