package com.porter.notification.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.notification.entity.NotificationPreference;
import com.porter.notification.service.NotificationPreferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/notification-preferences")
@RequiredArgsConstructor
public class NotificationPreferenceController {

  private final NotificationPreferenceService preferenceService;

  @GetMapping
  public ResponseEntity<ApiResponse<NotificationPreference>> getPreferences(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(
        preferenceService.getOrCreatePreferences(userId)));
  }

  @PutMapping
  public ResponseEntity<ApiResponse<NotificationPreference>> updatePreferences(
      Authentication auth, @RequestBody Map<String, Object> updates) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(
        preferenceService.updatePreferences(userId, updates)));
  }
}
