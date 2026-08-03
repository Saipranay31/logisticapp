package com.porter.emergency.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.emergency.entity.EmergencyAlert;
import com.porter.emergency.entity.EmergencyContact;
import com.porter.emergency.service.EmergencyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/emergency")
@RequiredArgsConstructor
public class EmergencyController {

  private final EmergencyService emergencyService;

  @PostMapping("/sos")
  public ResponseEntity<ApiResponse<Map<String, Object>>> triggerSOS(
      Authentication auth, @RequestBody Map<String, Object> body) {
    UUID userId = UUID.fromString(auth.getName());
    UUID rideId = body.containsKey("rideId") && body.get("rideId") != null
        ? UUID.fromString((String) body.get("rideId"))
        : null;
    String alertType = (String) body.getOrDefault("alertType", "SOS");
    String description = (String) body.getOrDefault("description", "");
    Double lat = body.containsKey("latitude") ? ((Number) body.get("latitude")).doubleValue() : null;
    Double lng = body.containsKey("longitude") ? ((Number) body.get("longitude")).doubleValue() : null;

    EmergencyAlert alert = emergencyService.triggerSOS(userId, rideId, alertType, description, lat, lng);

    return ResponseEntity.ok(ApiResponse.success(Map.of(
        "alertId", alert.getId(),
        "status", "SOS_ACTIVATED",
        "message", "Emergency alert sent. Help is on the way.")));
  }

  @GetMapping("/contacts")
  public ResponseEntity<ApiResponse<List<EmergencyContact>>> getContacts(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(emergencyService.getContacts(userId)));
  }

  @PostMapping("/contacts")
  public ResponseEntity<ApiResponse<EmergencyContact>> addContact(
      Authentication auth, @RequestBody Map<String, String> body) {
    UUID userId = UUID.fromString(auth.getName());
    EmergencyContact contact = emergencyService.addContact(
        userId, body.get("name"), body.get("phone"), body.getOrDefault("relation", ""));
    return ResponseEntity.ok(ApiResponse.success(contact));
  }

  @DeleteMapping("/contacts/{contactId}")
  public ResponseEntity<ApiResponse<Void>> deleteContact(
      Authentication auth, @PathVariable UUID contactId) {
    UUID userId = UUID.fromString(auth.getName());
    emergencyService.deleteContact(userId, contactId);
    return ResponseEntity.ok(ApiResponse.success("Contact deleted", null));
  }
}
