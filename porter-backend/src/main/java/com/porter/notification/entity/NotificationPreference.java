package com.porter.notification.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.UUID;

@Entity
@Table(name = "notification_preferences", indexes = {
    @Index(name = "idx_notif_pref_user", columnList = "user_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationPreference {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private UUID id;

  @Column(name = "user_id", nullable = false, unique = true)
  private UUID userId;

  // Notification Types
  @Builder.Default
  @Column(name = "ride_updates_enabled", nullable = false)
  private Boolean rideUpdatesEnabled = true;

  @Builder.Default
  @Column(name = "payment_notifications_enabled", nullable = false)
  private Boolean paymentNotificationsEnabled = true;

  @Builder.Default
  @Column(name = "promotional_enabled", nullable = false)
  private Boolean promotionalEnabled = false;

  @Builder.Default
  @Column(name = "system_alerts_enabled", nullable = false)
  private Boolean systemAlertsEnabled = true;

  // Delivery Channels
  @Builder.Default
  @Column(name = "fcm_enabled", nullable = false)
  private Boolean fcmEnabled = true;

  @Builder.Default
  @Column(name = "sms_enabled", nullable = false)
  private Boolean smsEnabled = false;

  @Builder.Default
  @Column(name = "email_enabled", nullable = false)
  private Boolean emailEnabled = false;

  // Quiet Hours
  @Builder.Default
  @Column(name = "quiet_hours_enabled", nullable = false)
  private Boolean quietHoursEnabled = false;

  @Column(name = "quiet_hours_start")
  private LocalTime quietHoursStart;

  @Column(name = "quiet_hours_end")
  private LocalTime quietHoursEnd;

  // Frequency Control
  @Builder.Default
  @Column(name = "max_notifications_per_day", nullable = false)
  private Integer maxNotificationsPerDay = 20;

  @Builder.Default
  @Column(name = "created_at", nullable = false, updatable = false)
  private LocalDateTime createdAt = LocalDateTime.now();

  @Builder.Default
  @Column(name = "updated_at", nullable = false)
  private LocalDateTime updatedAt = LocalDateTime.now();
}
