package com.porter.ride.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "ride_disputes", indexes = {
    @Index(name = "idx_dispute_ride", columnList = "ride_id"),
    @Index(name = "idx_dispute_status", columnList = "status")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RideDispute extends BaseEntity {

  @Column(name = "ride_id", nullable = false, unique = true)
  private UUID rideId;

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(nullable = false, length = 100)
  private String reason; // WRONG_FARE, DRIVER_BEHAVIOUR, ROUTE_DEVIATION, ITEM_DAMAGED, OTHER

  @Column(columnDefinition = "TEXT")
  private String description;

  @Column(nullable = false, length = 20)
  private String status = "OPEN"; // OPEN, UNDER_REVIEW, APPROVED, REJECTED

  @Column(name = "admin_notes", columnDefinition = "TEXT")
  private String adminNotes;

  @Column(name = "refund_amount")
  private Double refundAmount;

  @Column(name = "resolved_at")
  private LocalDateTime resolvedAt;
}
