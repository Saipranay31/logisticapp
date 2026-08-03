package com.porter.notification.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

/**
 * Stores FCM device tokens for push notifications.
 * Each user can have multiple tokens (multiple devices).
 */
@Entity
@Table(name = "device_tokens", uniqueConstraints = {
    @UniqueConstraint(columnNames = { "user_id", "token" })
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeviceToken extends BaseEntity {

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String token;

  @Column(nullable = false)
  private String platform; // ANDROID, IOS
}
