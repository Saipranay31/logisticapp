package com.porter.auth.service;

import com.porter.auth.entity.AccountLockout;
import com.porter.auth.entity.OtpAttemptLog;
import com.porter.auth.repository.AccountLockoutRepository;
import com.porter.auth.repository.OtpAttemptLogRepository;
import com.porter.common.exception.BadRequestException;
import com.porter.common.exception.TooManyRequestsException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * OTP and authentication rate limiting.
 * Prevents brute force, SMS flooding, and account takeover.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RateLimitService {

  private final OtpAttemptLogRepository otpAttemptLogRepository;
  private final AccountLockoutRepository accountLockoutRepository;

  @Value("${auth.rate-limit.otp-send-max-per-15min:3}")
  private int maxOtpSendPer15Min;

  @Value("${auth.rate-limit.otp-verify-max-per-otp:3}")
  private int maxOtpVerifyAttempts;

  @Value("${auth.rate-limit.account-lockout-threshold:5}")
  private int accountLockoutThreshold;

  @Value("${auth.rate-limit.account-lockout-duration-min:30}")
  private int accountLockoutDurationMin;

  /**
   * Check if phone can send OTP. Max 3 per 15 min.
   */
  public void validateOtpSendLimit(String phone, String ipAddress) {
    checkAccountLocked(phone);

    LocalDateTime fifteenMinAgo = LocalDateTime.now().minusMinutes(15);
    List<OtpAttemptLog> recent = otpAttemptLogRepository
        .findByPhoneAndAttemptTypeAndAttemptedAtAfter(phone, "SEND", fifteenMinAgo);

    if (recent.size() >= maxOtpSendPer15Min) {
      log.warn("OTP send rate limit exceeded for phone: {}", phone);
      throw new TooManyRequestsException("Too many OTP requests. Please try again in 15 minutes.");
    }
  }

  /**
   * Check if OTP can be verified. Max 3 failed attempts per 5 min.
   */
  public void validateOtpVerifyLimit(String phone) {
    checkAccountLocked(phone);

    LocalDateTime fiveMinAgo = LocalDateTime.now().minusMinutes(5);
    List<OtpAttemptLog> failedAttempts = otpAttemptLogRepository
        .findByPhoneAndAttemptTypeAndStatusAndAttemptedAtAfter(phone, "VERIFY", "FAILED", fiveMinAgo);

    if (failedAttempts.size() >= maxOtpVerifyAttempts) {
      log.warn("OTP verify limit exceeded for phone: {}", phone);
      lockAccount(phone, "Too many failed OTP verification attempts");
      throw new BadRequestException("Too many failed attempts. Account locked for 30 minutes.");
    }
  }

  @Transactional
  public void logOtpSendAttempt(String phone, String ipAddress, boolean success) {
    otpAttemptLogRepository.save(OtpAttemptLog.builder()
        .phone(phone)
        .attemptType("SEND")
        .status(success ? "SUCCESS" : "FAILED")
        .ipAddress(ipAddress)
        .build());
  }

  @Transactional
  public void logOtpVerifyAttempt(String phone, String ipAddress, boolean success) {
    otpAttemptLogRepository.save(OtpAttemptLog.builder()
        .phone(phone)
        .attemptType("VERIFY")
        .status(success ? "SUCCESS" : "FAILED")
        .ipAddress(ipAddress)
        .build());

    if (!success) {
      incrementFailedAttempts(phone);
    }
  }

  private void checkAccountLocked(String phone) {
    accountLockoutRepository.findByPhone(phone).ifPresent(lock -> {
      if (lock.getLockedUntil() != null && lock.getLockedUntil().isAfter(LocalDateTime.now())) {
        log.warn("Account locked for phone: {}", phone);
        throw new TooManyRequestsException("Account temporarily locked. Try again later.");
      } else {
        accountLockoutRepository.delete(lock);
      }
    });
  }

  @Transactional
  private void incrementFailedAttempts(String phone) {
    AccountLockout lock = accountLockoutRepository.findByPhone(phone)
        .orElse(AccountLockout.builder()
            .phone(phone)
            .failedAttempts(0)
            .reason("Failed OTP verification attempts")
            .build());

    lock.setFailedAttempts(lock.getFailedAttempts() + 1);

    if (lock.getFailedAttempts() >= accountLockoutThreshold) {
      lock.setLockedUntil(LocalDateTime.now().plusMinutes(accountLockoutDurationMin));
      log.warn("Account locked: {} ({} failed attempts)", phone, lock.getFailedAttempts());
    }

    accountLockoutRepository.save(lock);
  }

  @Transactional
  public void unlockAccount(String phone) {
    accountLockoutRepository.deleteByPhone(phone);
    log.info("Account unlocked: {}", phone);
  }

  @Transactional
  private void lockAccount(String phone, String reason) {
    AccountLockout lock = accountLockoutRepository.findByPhone(phone)
        .orElse(new AccountLockout());
    lock.setPhone(phone);
    lock.setLockedUntil(LocalDateTime.now().plusMinutes(accountLockoutDurationMin));
    lock.setReason(reason);
    lock.setFailedAttempts(accountLockoutThreshold);
    accountLockoutRepository.save(lock);
  }
}
