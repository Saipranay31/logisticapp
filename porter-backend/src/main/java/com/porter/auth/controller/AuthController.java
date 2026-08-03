package com.porter.auth.controller;

import com.porter.auth.dto.*;
import com.porter.auth.service.AuthService;
import com.porter.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

/**
 * Authentication endpoints for OTP login, admin login, and token refresh.
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

  private final AuthService authService;

  /**
   * Send OTP to phone number.
   * POST /api/auth/otp/send
   */
  @PostMapping("/otp/send")
  public ResponseEntity<ApiResponse<String>> sendOtp(@Valid @RequestBody SendOtpRequest request) {
    String message = authService.sendOtp(request);
    return ResponseEntity.ok(ApiResponse.success(message, null));
  }

  /**
   * Verify OTP and get auth tokens.
   * POST /api/auth/otp/verify
   * ✅ SIMPLIFIED: Just JSON request, no multipart upload here
   * Profile image upload moved to KYC/Complete Profile screen
   */
  @PostMapping("/otp/verify")
  public ResponseEntity<ApiResponse<AuthResponse>> verifyOtp(@RequestBody VerifyOtpRequest request) {
    AuthResponse response = authService.verifyOtp(request);
    return ResponseEntity.ok(ApiResponse.success("Authentication successful", response));
  }

  /**
   * Admin login with email/password.
   * POST /api/auth/admin/login
   */
  @PostMapping("/admin/login")
  public ResponseEntity<ApiResponse<AuthResponse>> adminLogin(@Valid @RequestBody AdminLoginRequest request) {
    AuthResponse response = authService.adminLogin(request);
    return ResponseEntity.ok(ApiResponse.success("Admin login successful", response));
  }

  /**
   * Refresh access token.
   * POST /api/auth/refresh
   */
  @PostMapping("/refresh")
  public ResponseEntity<ApiResponse<AuthResponse>> refreshToken(@RequestParam String refreshToken) {
    AuthResponse response = authService.refreshToken(refreshToken);
    return ResponseEntity.ok(ApiResponse.success("Token refreshed", response));
  }
}
