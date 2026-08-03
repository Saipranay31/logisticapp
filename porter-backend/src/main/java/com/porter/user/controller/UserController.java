package com.porter.user.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.user.dto.AddressRequest;
import com.porter.user.dto.UserProfileDto;
import com.porter.user.entity.UserAddress;
import com.porter.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

  private final UserService userService;

  @GetMapping("/profile")
  public ResponseEntity<ApiResponse<UserProfileDto>> getProfile(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(userService.getProfile(userId)));
  }

  @PutMapping("/profile")
  public ResponseEntity<ApiResponse<UserProfileDto>> updateProfile(
      Authentication auth,
      @RequestParam(required = false) String fullName,
      @RequestParam(required = false) String avatarUrl) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(userService.updateProfile(userId, fullName, avatarUrl)));
  }

  @GetMapping("/addresses")
  public ResponseEntity<ApiResponse<List<UserAddress>>> getAddresses(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(userService.getAddresses(userId)));
  }

  @PostMapping("/addresses")
  public ResponseEntity<ApiResponse<UserAddress>> addAddress(
      Authentication auth, @Valid @RequestBody AddressRequest request) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(userService.addAddress(userId, request)));
  }

  @DeleteMapping("/addresses/{addressId}")
  public ResponseEntity<ApiResponse<Void>> deleteAddress(
      Authentication auth, @PathVariable UUID addressId) {
    UUID userId = UUID.fromString(auth.getName());
    userService.deleteAddress(userId, addressId);
    return ResponseEntity.ok(ApiResponse.success("Address deleted", null));
  }
}
