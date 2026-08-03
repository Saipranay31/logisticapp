package com.porter.notification.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.notification.entity.Notification;
import com.porter.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

  private final NotificationService notificationService;

  @GetMapping
  public ResponseEntity<ApiResponse<List<Notification>>> getNotifications(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(notificationService.getUserNotifications(userId)));
  }

  @PostMapping("/{id}/read")
  public ResponseEntity<ApiResponse<Void>> markAsRead(@PathVariable UUID id) {
    notificationService.markAsRead(id);
    return ResponseEntity.ok(ApiResponse.success("Marked as read", null));
  }

  @GetMapping("/unread-count")
  public ResponseEntity<ApiResponse<Long>> getUnreadCount(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(notificationService.getUnreadCount(userId)));
  }

  /**
   * Register FCM device token.
   * Called from Flutter apps after getting the FCM token.
   */
  @PostMapping("/device-token")
  public ResponseEntity<ApiResponse<Void>> registerDeviceToken(
      Authentication auth, @RequestBody Map<String, String> body) {
    UUID userId = UUID.fromString(auth.getName());
    String token = body.get("token");
    String platform = body.getOrDefault("platform", "ANDROID");
    notificationService.registerDeviceToken(userId, token, platform);
    return ResponseEntity.ok(ApiResponse.success("Device token registered", null));
  }

  /**
   * Remove FCM device token (on logout).
   */
  @DeleteMapping("/device-token")
  public ResponseEntity<ApiResponse<Void>> removeDeviceToken(
      Authentication auth, @RequestBody Map<String, String> body) {
    UUID userId = UUID.fromString(auth.getName());
    notificationService.removeDeviceToken(userId, body.get("token"));
    return ResponseEntity.ok(ApiResponse.success("Device token removed", null));
  }
}
