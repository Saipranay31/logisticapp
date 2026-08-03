package com.porter.auth.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "otp_attempt_log", indexes = {
    @Index(name = "idx_otp_attempts_phone", columnList = "phone, attempted_at"),
    @Index(name = "idx_otp_attempts_ip", columnList = "ip_address, attempted_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OtpAttemptLog extends BaseEntity {

  @Column(nullable = false, length = 20)
  private String phone;

  @Column(name = "attempt_type", nullable = false, length = 20)
  private String attemptType; // SEND, VERIFY

  @Column(nullable = false, length = 20)
  private String status; // SUCCESS, FAILED

  @Column(name = "ip_address", length = 45)
  private String ipAddress;

  @Builder.Default
  @Column(name = "attempted_at", nullable = false)
  private LocalDateTime attemptedAt = LocalDateTime.now();
}
