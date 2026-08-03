package com.porter.auth.service;

import com.porter.auth.dto.*;
import com.porter.auth.entity.OtpRecord;
import com.porter.auth.entity.User;
import com.porter.auth.repository.OtpRepository;
import com.porter.auth.repository.UserRepository;
import com.porter.common.enums.Role;
import com.porter.common.enums.KycStatus;
import com.porter.common.exception.BadRequestException;
import com.porter.common.exception.UnauthorizedException;
import com.porter.config.JwtTokenProvider;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.file.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Random;

/**
 * Authentication service handling OTP login (user/driver) and email/password
 * login (admin).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

  private final UserRepository userRepository;
  private final OtpRepository otpRepository;
  private final DriverProfileRepository driverProfileRepository;
  private final JwtTokenProvider jwtTokenProvider;
  private final PasswordEncoder passwordEncoder;
  private final RateLimitService rateLimitService;
  private final FileStorageService fileStorageService;
  private final Random random = new Random();

  /**
   * Send OTP to phone number (simulated — logs to console).
   */
  @Transactional
  public String sendOtp(SendOtpRequest request) {
    // Rate limit check
    rateLimitService.validateOtpSendLimit(request.getPhone(), null);

    String otpCode = String.format("%06d", random.nextInt(999999));

    OtpRecord otpRecord = OtpRecord.builder()
        .phone(request.getPhone())
        .otpCode(otpCode)
        .purpose("LOGIN")
        .isVerified(false)
        .expiresAt(LocalDateTime.now().plusMinutes(5))
        .build();

    otpRepository.save(otpRecord);

    // Log attempt
    rateLimitService.logOtpSendAttempt(request.getPhone(), null, true);

    // Simulated SMS — log OTP to console
    log.info("========================================");
    log.info("OTP for {}: {}", request.getPhone(), otpCode);
    log.info("========================================");

    return "OTP sent successfully to " + request.getPhone();
  }

  /**
   * Verify OTP and authenticate user. Creates new user if not exists.
   */
  @Transactional
  public AuthResponse verifyOtp(VerifyOtpRequest request) {
    // Rate limit check
    rateLimitService.validateOtpVerifyLimit(request.getPhone());

    // Find latest OTP for this phone
    OtpRecord otpRecord = otpRepository
        .findTopByPhoneAndPurposeOrderByCreatedAtDesc(request.getPhone(), "LOGIN")
        .orElseThrow(() -> new BadRequestException("No OTP found for this phone number"));

    // Validate OTP
    if (otpRecord.isVerified()) {
      rateLimitService.logOtpVerifyAttempt(request.getPhone(), null, false);
      throw new BadRequestException("OTP already used");
    }
    if (otpRecord.getExpiresAt().isBefore(LocalDateTime.now())) {
      rateLimitService.logOtpVerifyAttempt(request.getPhone(), null, false);
      throw new BadRequestException("OTP has expired");
    }
    if (!otpRecord.getOtpCode().equals(request.getOtp())) {
      rateLimitService.logOtpVerifyAttempt(request.getPhone(), null, false);
      throw new BadRequestException("Invalid OTP");
    }

    // Log successful verification
    rateLimitService.logOtpVerifyAttempt(request.getPhone(), null, true);

    // Mark OTP as verified
    otpRecord.setVerified(true);
    otpRepository.save(otpRecord);

    // Find or create user
    Role role = Role.valueOf(request.getRole().toUpperCase());
    Optional<User> existingUser = userRepository.findByPhone(request.getPhone());

    boolean isNewUser = existingUser.isEmpty();
    User user;

    if (isNewUser) {
      // ✅ FIX: Use fullName from request if provided, otherwise use phone as placeholder
      String driverName = request.getFullName() != null && !request.getFullName().isBlank()
          ? request.getFullName()
          : "Driver_" + request.getPhone(); // Temporary name, will be updated in KYC

      user = User.builder()
          .phone(request.getPhone())
          .fullName(driverName)
          .role(role)
          .isActive(true)
          .build();
      user = userRepository.save(user);
      log.info("✅ New {} registered: {} with name: {}", role, user.getId(), driverName);

      // ✅ Create driver profile if DRIVER role
      if (role == Role.DRIVER) {
        DriverProfile driverProfile = DriverProfile.builder()
            .userId(user.getId())
            .kycStatus(KycStatus.PENDING)
            .isOnline(false)
            .rating(5.0)
            .totalRides(0)
            .build();
        driverProfileRepository.save(driverProfile);
        log.info("✅ Driver profile created for user: {}", user.getId());
      }
    } else {
      user = existingUser.get();
    }

    // Generate tokens
    String accessToken = jwtTokenProvider.generateToken(user.getId(), user.getRole().name());
    String refreshToken = jwtTokenProvider.generateRefreshToken(user.getId());

    return AuthResponse.builder()
        .userId(user.getId())
        .fullName(user.getFullName())
        .role(user.getRole().name())
        .accessToken(accessToken)
        .refreshToken(refreshToken)
        .isNewUser(isNewUser)
        .build();
  }

  /**
   * Verify OTP with optional profile image upload (overloaded method).
   * ✅ SIMPLIFIED: Now just delegates to standard verification
   */
  @Transactional
  public AuthResponse verifyOtp(VerifyOtpRequest request, MultipartFile profileImage) throws IOException {
    // ✅ SIMPLIFIED: Just perform OTP verification, NO image upload during login
    // Profile image upload moved to KYC/Complete Profile screen
    return verifyOtp(request);
  }

  public AuthResponse adminLogin(AdminLoginRequest request) {
    User admin = userRepository.findByEmailAndRole(request.getEmail(), Role.ADMIN)
        .orElseThrow(() -> new UnauthorizedException("Invalid email or password"));

    if (!passwordEncoder.matches(request.getPassword(), admin.getPasswordHash())) {
      throw new UnauthorizedException("Invalid email or password");
    }

    if (!admin.isActive()) {
      throw new UnauthorizedException("Account is deactivated");
    }

    String accessToken = jwtTokenProvider.generateToken(admin.getId(), admin.getRole().name());
    String refreshToken = jwtTokenProvider.generateRefreshToken(admin.getId());

    return AuthResponse.builder()
        .userId(admin.getId())
        .fullName(admin.getFullName())
        .role(admin.getRole().name())
        .accessToken(accessToken)
        .refreshToken(refreshToken)
        .isNewUser(false)
        .build();
  }

  /**
   * Refresh access token.
   */
  public AuthResponse refreshToken(String refreshToken) {
    if (!jwtTokenProvider.validateToken(refreshToken)) {
      throw new UnauthorizedException("Invalid or expired refresh token");
    }

    var userId = jwtTokenProvider.getUserIdFromToken(refreshToken);
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new UnauthorizedException("User not found"));

    String newAccessToken = jwtTokenProvider.generateToken(user.getId(), user.getRole().name());
    String newRefreshToken = jwtTokenProvider.generateRefreshToken(user.getId());

    return AuthResponse.builder()
        .userId(user.getId())
        .fullName(user.getFullName())
        .role(user.getRole().name())
        .accessToken(newAccessToken)
        .refreshToken(newRefreshToken)
        .isNewUser(false)
        .build();
  }
}
