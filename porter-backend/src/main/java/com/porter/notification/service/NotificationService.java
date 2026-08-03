package com.porter.notification.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.porter.notification.entity.DeviceToken;
import com.porter.notification.entity.Notification;
import com.porter.notification.repository.DeviceTokenRepository;
import com.porter.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Notification service supporting:
 * 1. Database persistence
 * 2. WebSocket real-time push
 * 3. FCM push notification (if Firebase is configured)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {

  private final NotificationRepository notificationRepository;
  private final DeviceTokenRepository deviceTokenRepository;
  private final SimpMessagingTemplate messagingTemplate;

  /**
   * Send and persist a notification. Pushes via WebSocket and FCM.
   */
  public Notification sendNotification(UUID userId, String title, String body, String type) {
    // 1. Persist
    Notification notification = Notification.builder()
        .userId(userId)
        .title(title)
        .body(body)
        .type(type)
        .isRead(false)
        .build();
    notification = notificationRepository.save(notification);

    // 2. WebSocket push
    messagingTemplate.convertAndSend("/topic/user/" + userId + "/notifications",
        Map.of("title", title, "body", body, "type", type));

    // 3. FCM push (if configured)
    sendFcmToUser(userId, title, body, type, null);

    log.info("📱 Notification to {}: [{}] {}", userId, title, body);
    return notification;
  }

  /**
   * Send ride request notification with full ride details for FCM payload
   */
  public Notification sendRideRequestNotification(UUID driverId, String rideId, String pickupAddress,
      String dropAddress, Double estimatedFare, Double estimatedDistance, Double pickupLatitude, Double pickupLongitude, Double dropLatitude, Double dropLongitude) {
    // 1. Persist notification
    Notification notification = Notification.builder()
        .userId(driverId)
        .title("New Ride Request")
        .body("Pickup: " + pickupAddress)
        .type("RIDE_REQUEST")
        .isRead(false)
        .build();
    notification = notificationRepository.save(notification);

    // 2. WebSocket push
    Map<String, String> wsData = new java.util.HashMap<>();
    wsData.put("title", "New Ride Request");
    wsData.put("body", "Pickup: " + pickupAddress);
    wsData.put("type", "RIDE_REQUEST");
    wsData.put("rideId", rideId);
    wsData.put("pickupAddress", pickupAddress);
    wsData.put("dropAddress", dropAddress);
    wsData.put("fare", estimatedFare.toString());
    wsData.put("distance", estimatedDistance.toString());
    wsData.put("pickupLatitude", pickupLatitude.toString());
    wsData.put("pickupLongitude", pickupLongitude.toString());
    wsData.put("dropLatitude", dropLatitude.toString());
    wsData.put("dropLongitude", dropLongitude.toString());
    messagingTemplate.convertAndSend("/topic/driver/" + driverId + "/ride-request", wsData);

    // 3. FCM push with complete ride details including coordinates
    Map<String, String> rideData = new java.util.HashMap<>();
    rideData.put("rideId", rideId);
    rideData.put("type", "RIDE_REQUEST");
    rideData.put("pickupAddress", pickupAddress);
    rideData.put("dropAddress", dropAddress);
    rideData.put("fare", estimatedFare.toString());
    rideData.put("distance", estimatedDistance.toString());
    rideData.put("pickupLatitude", pickupLatitude.toString());
    rideData.put("pickupLongitude", pickupLongitude.toString());
    rideData.put("dropLatitude", dropLatitude.toString());
    rideData.put("dropLongitude", dropLongitude.toString());
    sendFcmToUser(driverId, "New Ride Request", "Pickup: " + pickupAddress, "RIDE_REQUEST", rideData);

    log.info("📱 Ride Request to {}: {} → {}", driverId, pickupAddress, dropAddress);
    return notification;
  }

  /**
   * Send FCM push to all registered devices of a user.
   */
  private void sendFcmToUser(UUID userId, String title, String body, String type, Map<String, String> additionalData) {
    // ✅ Check if Firebase is initialized
    if (FirebaseApp.getApps().isEmpty()) {
      log.warn("⚠️  Firebase NOT initialized - FCM push skipped for user {}", userId);
      return;
    }

    // ✅ Get all device tokens for the user
    List<DeviceToken> tokens = deviceTokenRepository.findByUserId(userId);
    if (tokens.isEmpty()) {
      log.warn("⚠️  No device tokens found for user {} - cannot send FCM", userId);
      return;
    }

    log.info("📱 FCM: Sending to {} device(s) for user {}", tokens.size(), userId);

    // ✅ Send to each device
    for (DeviceToken dt : tokens) {
      try {
        Message.Builder messageBuilder = Message.builder()
            .setToken(dt.getToken())
            .setNotification(com.google.firebase.messaging.Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build())
            .putData("type", type)
            .putData("userId", userId.toString());

        // ✅ Add additional ride data if provided
        if (additionalData != null) {
          for (Map.Entry<String, String> entry : additionalData.entrySet()) {
            messageBuilder.putData(entry.getKey(), entry.getValue());
          }
        }

        Message message = messageBuilder.build();
        String messageId = FirebaseMessaging.getInstance().send(message);
        log.info("✅ FCM sent to {}: messageId={}", dt.getToken().substring(0, 20), messageId);
      } catch (Exception e) {
        log.error("❌ FCM failed for token {}: {}", dt.getToken().substring(0, 20), e.getMessage(), e);
        // Remove invalid/unregistered tokens
        String errorMsg = e.getMessage() != null ? e.getMessage().toLowerCase() : "";
        if (errorMsg.contains("notregistered") || errorMsg.contains("not-registered") || errorMsg.contains("unregistered") || errorMsg.contains("not found") || errorMsg.contains("not_found")) {
          log.info("🗑️  Removing invalid/unregistered token: {}", dt.getToken().substring(0, 20));
          deviceTokenRepository.delete(dt);
        }
      }
    }
  }

  /**
   * Register or update FCM device token.
   */
  @Transactional
  public void registerDeviceToken(UUID userId, String token, String platform) {
    if (deviceTokenRepository.findByUserIdAndToken(userId, token).isEmpty()) {
      deviceTokenRepository.save(DeviceToken.builder()
          .userId(userId)
          .token(token)
          .platform(platform)
          .build());
      log.info("Device token registered for user {}", userId);
    }
  }

  /**
   * Remove FCM device token (on logout).
   */
  @Transactional
  public void removeDeviceToken(UUID userId, String token) {
    deviceTokenRepository.deleteByUserIdAndToken(userId, token);
  }

  public List<Notification> getUserNotifications(UUID userId) {
    return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId);
  }

  public void markAsRead(UUID notificationId) {
    notificationRepository.findById(notificationId).ifPresent(n -> {
      n.setRead(true);
      notificationRepository.save(n);
    });
  }

  public long getUnreadCount(UUID userId) {
    return notificationRepository.countByUserIdAndIsRead(userId, false);
  }
}
