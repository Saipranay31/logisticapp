package com.porter.auth.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * OTP record for phone-based authentication.
 */
@Entity
@Table(name = "otp_records")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OtpRecord extends BaseEntity {

  @Column(nullable = false)
  private String phone;

  @Column(name = "otp_code", nullable = false)
  private String otpCode;

  @Column(nullable = false)
  private String purpose;

  @Column(name = "is_verified", nullable = false)
  private boolean isVerified = false;

  @Column(name = "expires_at", nullable = false)
  private LocalDateTime expiresAt;
}
