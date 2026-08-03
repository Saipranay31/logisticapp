package com.porter.notification.service;

import com.porter.notification.entity.NotificationPreference;
import com.porter.notification.repository.NotificationPreferenceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationPreferenceService {

  private final NotificationPreferenceRepository preferenceRepository;

  public NotificationPreference getOrCreatePreferences(UUID userId) {
    return preferenceRepository.findByUserId(userId)
        .orElseGet(() -> preferenceRepository.save(
            NotificationPreference.builder().userId(userId).build()));
  }

  @Transactional
  public NotificationPreference updatePreferences(UUID userId, Map<String, Object> updates) {
    NotificationPreference prefs = getOrCreatePreferences(userId);

    if (updates.containsKey("rideUpdatesEnabled"))
      prefs.setRideUpdatesEnabled((Boolean) updates.get("rideUpdatesEnabled"));
    if (updates.containsKey("paymentNotificationsEnabled"))
      prefs.setPaymentNotificationsEnabled((Boolean) updates.get("paymentNotificationsEnabled"));
    if (updates.containsKey("promotionalEnabled"))
      prefs.setPromotionalEnabled((Boolean) updates.get("promotionalEnabled"));
    if (updates.containsKey("systemAlertsEnabled"))
      prefs.setSystemAlertsEnabled((Boolean) updates.get("systemAlertsEnabled"));
    if (updates.containsKey("fcmEnabled"))
      prefs.setFcmEnabled((Boolean) updates.get("fcmEnabled"));
    if (updates.containsKey("smsEnabled"))
      prefs.setSmsEnabled((Boolean) updates.get("smsEnabled"));
    if (updates.containsKey("emailEnabled"))
      prefs.setEmailEnabled((Boolean) updates.get("emailEnabled"));
    if (updates.containsKey("quietHoursEnabled"))
      prefs.setQuietHoursEnabled((Boolean) updates.get("quietHoursEnabled"));
    if (updates.containsKey("quietHoursStart"))
      prefs.setQuietHoursStart(LocalTime.parse((String) updates.get("quietHoursStart")));
    if (updates.containsKey("quietHoursEnd"))
      prefs.setQuietHoursEnd(LocalTime.parse((String) updates.get("quietHoursEnd")));
    if (updates.containsKey("maxNotificationsPerDay"))
      prefs.setMaxNotificationsPerDay(((Number) updates.get("maxNotificationsPerDay")).intValue());

    prefs.setUpdatedAt(LocalDateTime.now());
    return preferenceRepository.save(prefs);
  }

  /**
   * Check if notification should be sent based on user preferences.
   */
  public boolean shouldSendNotification(UUID userId, String notificationType, String channel) {
    NotificationPreference prefs = getOrCreatePreferences(userId);

    // Check notification type
    boolean typeEnabled = switch (notificationType) {
      case "RIDE_UPDATE" -> prefs.getRideUpdatesEnabled();
      case "PAYMENT", "PAYMENT_SUCCESS", "PAYMENT_RETRY" -> prefs.getPaymentNotificationsEnabled();
      case "PROMO" -> prefs.getPromotionalEnabled();
      case "SYSTEM", "SOS" -> prefs.getSystemAlertsEnabled();
      default -> true;
    };
    if (!typeEnabled)
      return false;

    // Check delivery channel
    boolean channelEnabled = switch (channel != null ? channel : "FCM") {
      case "FCM" -> prefs.getFcmEnabled();
      case "SMS" -> prefs.getSmsEnabled();
      case "EMAIL" -> prefs.getEmailEnabled();
      default -> true;
    };
    if (!channelEnabled)
      return false;

    // Check quiet hours
    if (prefs.getQuietHoursEnabled() && prefs.getQuietHoursStart() != null
        && prefs.getQuietHoursEnd() != null) {
      LocalTime now = LocalTime.now();
      if (isInQuietHours(now, prefs.getQuietHoursStart(), prefs.getQuietHoursEnd())) {
        return false;
      }
    }

    return true;
  }

  private boolean isInQuietHours(LocalTime now, LocalTime start, LocalTime end) {
    if (start.isBefore(end)) {
      return !now.isBefore(start) && now.isBefore(end);
    } else {
      // Crosses midnight (e.g. 22:00 - 08:00)
      return !now.isBefore(start) || now.isBefore(end);
    }
  }
}
