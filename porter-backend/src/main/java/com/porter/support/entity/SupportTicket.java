package com.porter.support.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "support_tickets", indexes = {
    @Index(name = "idx_tickets_user", columnList = "user_id"),
    @Index(name = "idx_tickets_status", columnList = "status")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupportTicket extends BaseEntity {

  @Column(name = "ticket_number", nullable = false, unique = true)
  private String ticketNumber;

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(name = "ride_id")
  private UUID rideId;

  @Column(nullable = false)
  private String subject;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String description;

  @Column(nullable = false, length = 50)
  private String category; // RIDE_ISSUE, PAYMENT, DRIVER, TECHNICAL

  @Builder.Default
  @Column(nullable = false, length = 20)
  private String priority = "MEDIUM"; // LOW, MEDIUM, HIGH, URGENT

  @Builder.Default
  @Column(nullable = false, length = 20)
  private String status = "OPEN"; // OPEN, IN_PROGRESS, WAITING_USER, RESOLVED, CLOSED

  @Column(name = "assigned_to_admin_id")
  private UUID assignedToAdminId;

  @Column(name = "resolved_at")
  private LocalDateTime resolvedAt;
}
