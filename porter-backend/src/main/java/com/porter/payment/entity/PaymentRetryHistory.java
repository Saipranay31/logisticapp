package com.porter.payment.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "payment_retry_history", indexes = {
    @Index(name = "idx_retry_payment", columnList = "payment_id"),
    @Index(name = "idx_retry_status", columnList = "status")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentRetryHistory extends BaseEntity {

  @Column(name = "payment_id", nullable = false)
  private UUID paymentId;

  @Column(name = "retry_attempt", nullable = false)
  private Integer retryAttempt;

  @Column(name = "status", nullable = false)
  private String status; // SUCCESS, FAILED, PENDING

  @Column(name = "error", columnDefinition = "TEXT")
  private String error;

  @Builder.Default
  @Column(name = "attempted_at", nullable = false)
  private LocalDateTime attemptedAt = LocalDateTime.now();
}
