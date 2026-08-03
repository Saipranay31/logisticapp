package com.porter.payment.entity;

import com.porter.common.entity.BaseEntity;
import com.porter.common.enums.PaymentMethod;
import com.porter.common.enums.PaymentStatus;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "payments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Payment extends BaseEntity {

  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(name = "driver_id")
  private UUID driverId;

  @Column(nullable = false)
  private double amount;

  @Enumerated(EnumType.STRING)
  @Column(name = "payment_method", nullable = false)
  private PaymentMethod paymentMethod = PaymentMethod.CASH;

  @Enumerated(EnumType.STRING)
  @Column(name = "payment_status", nullable = false)
  private PaymentStatus paymentStatus = PaymentStatus.PENDING;

  // Razorpay fields
  @Column(name = "razorpay_order_id")
  private String razorpayOrderId;

  @Column(name = "razorpay_payment_id")
  private String razorpayPaymentId;

  @Column(name = "razorpay_signature")
  private String razorpaySignature;

  // Retry fields
  @Builder.Default
  @Column(name = "retry_count", nullable = false)
  private Integer retryCount = 0;

  @Column(name = "last_retry_at")
  private LocalDateTime lastRetryAt;

  @Column(name = "next_retry_at")
  private LocalDateTime nextRetryAt;

  @Builder.Default
  @Column(name = "max_retries", nullable = false)
  private Integer maxRetries = 3;

  @Column(name = "error_message", columnDefinition = "TEXT")
  private String errorMessage;
}
