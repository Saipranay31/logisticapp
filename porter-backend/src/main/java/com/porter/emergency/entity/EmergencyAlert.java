package com.porter.emergency.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "emergency_alerts", indexes = {
    @Index(name = "idx_ea_user", columnList = "user_id"),
    @Index(name = "idx_ea_status", columnList = "status")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmergencyAlert extends BaseEntity {

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(name = "ride_id")
  private UUID rideId;

  private Double latitude;
  private Double longitude;

  @Column(name = "alert_type", nullable = false)
  private String alertType; // SOS, DRIVER_ISSUE, SAFETY_CONCERN

  @Column(columnDefinition = "TEXT")
  private String description;

  @Column(nullable = false)
  private String status = "OPEN"; // OPEN, ACKNOWLEDGED, RESOLVED

  @Column(name = "police_contacted", nullable = false)
  private Boolean policeContacted = false;

  @Column(name = "resolved_at")
  private LocalDateTime resolvedAt;
}
