package com.porter.auth.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "account_lockout", indexes = {
    @Index(name = "idx_lockout_phone", columnList = "phone")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AccountLockout extends BaseEntity {

  @Column(nullable = false, unique = true, length = 20)
  private String phone;

  @Builder.Default
  @Column(name = "failed_attempts", nullable = false)
  private Integer failedAttempts = 0;

  @Column(name = "locked_until")
  private LocalDateTime lockedUntil;

  @Column(length = 255)
  private String reason;
}
