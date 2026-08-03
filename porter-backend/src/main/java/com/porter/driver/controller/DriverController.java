package com.porter.driver.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.driver.dto.DriverProfileDto;
import com.porter.driver.entity.DriverDocument;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.entity.DriverVehicle;
import com.porter.driver.service.DriverService;
import com.porter.file.service.FileStorageService;
import com.porter.payment.entity.Payment;
import com.porter.payment.repository.PaymentRepository;
import com.porter.ride.service.RatingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/driver")
@RequiredArgsConstructor
@Slf4j
public class DriverController {

  private final DriverService driverService;
  private final RatingService ratingService;
  private final PaymentRepository paymentRepository;
  private final FileStorageService fileStorageService;

  @GetMapping("/profile")
  public ResponseEntity<ApiResponse<DriverProfileDto>> getProfile(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(driverService.getDriverProfile(userId)));
  }

  @PostMapping(value = "/profile", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public ResponseEntity<ApiResponse<DriverProfile>> createProfile(
      Authentication auth,
      @RequestParam String licenseNumber,
      @RequestParam(required = false) MultipartFile profilePicture) {
    try {
      UUID userId = UUID.fromString(auth.getName());

      // Upload profile picture if provided
      String profilePictureUrl = null;
      if (profilePicture != null && !profilePicture.isEmpty()) {
        profilePictureUrl = fileStorageService.saveFile(profilePicture, "drivers");
        log.info("✅ Profile picture uploaded: {}", profilePictureUrl);
      }

      return ResponseEntity.ok(ApiResponse.success(
          driverService.createDriverProfile(userId, licenseNumber, profilePictureUrl)));
    } catch (IOException e) {
      log.error("❌ File upload failed: {}", e.getMessage());
      return ResponseEntity.badRequest().body(
          ApiResponse.error("File upload failed: " + e.getMessage()));
    }
  }

  @PutMapping(value = "/profile", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public ResponseEntity<ApiResponse<DriverProfile>> updateProfile(
      Authentication auth,
      @RequestParam(required = false) String licenseNumber,
      @RequestParam(required = false) String fullName,
      @RequestParam(required = false) MultipartFile profilePicture) {
    try {
      UUID userId = UUID.fromString(auth.getName());

      // Upload profile picture if provided
      String profilePictureUrl = null;
      if (profilePicture != null && !profilePicture.isEmpty()) {
        profilePictureUrl = fileStorageService.saveFile(profilePicture, "drivers");
        log.info("✅ Profile picture uploaded: {}", profilePictureUrl);
      }

      return ResponseEntity.ok(ApiResponse.success(
          driverService.updateDriverProfile(userId, licenseNumber, fullName, profilePictureUrl)));
    } catch (IOException e) {
      log.error("❌ File upload failed: {}", e.getMessage());
      return ResponseEntity.badRequest().body(
          ApiResponse.error("File upload failed: " + e.getMessage()));
    }
  }

  @PostMapping("/toggle-online")
  public ResponseEntity<ApiResponse<DriverProfileDto>> toggleOnline(
      Authentication auth, @RequestParam boolean online,
      @RequestParam(required = false) Double latitude,
      @RequestParam(required = false) Double longitude) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(
        driverService.toggleOnlineStatus(userId, online, latitude, longitude)));
  }

  // ─── VEHICLE REGISTRATION ───

  @PostMapping("/vehicle")
  public ResponseEntity<ApiResponse<DriverVehicle>> registerVehicle(
      Authentication auth, @RequestBody Map<String, String> body) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(
        driverService.registerVehicle(userId,
            body.get("vehicleType"), body.get("vehicleNumber"),
            body.getOrDefault("vehicleModel", ""))));
  }

  // ─── KYC DOCUMENT MANAGEMENT ───

  @PostMapping(value = "/documents", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public ResponseEntity<ApiResponse<DriverDocument>> uploadDocument(
      Authentication auth,
      @RequestParam String documentType,
      @RequestParam MultipartFile documentFile) {
    try {
      UUID userId = UUID.fromString(auth.getName());

      // Upload document file
      String documentUrl = fileStorageService.saveFile(documentFile, "kyc-documents");
      log.info("✅ KYC document uploaded: {}", documentUrl);

      return ResponseEntity.ok(ApiResponse.success(
          driverService.uploadDocument(userId, documentType, documentUrl)));
    } catch (IOException e) {
      log.error("❌ Document upload failed: {}", e.getMessage());
      return ResponseEntity.badRequest().body(
          ApiResponse.error("Document upload failed: " + e.getMessage()));
    }
  }

  @GetMapping("/documents")
  public ResponseEntity<ApiResponse<List<DriverDocument>>> getDocuments(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(driverService.getDocuments(userId)));
  }

  @PostMapping("/kyc/submit")
  public ResponseEntity<ApiResponse<DriverProfileDto>> submitKyc(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(driverService.submitKyc(userId)));
  }

  // ─── RATINGS ───

  @GetMapping("/{driverId}/ratings")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getDriverRatings(@PathVariable UUID driverId) {
    return ResponseEntity.ok(ApiResponse.success(ratingService.getDriverRatings(driverId)));
  }

  @GetMapping("/{driverId}/reviews")
  public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getDriverReviews(
      @PathVariable UUID driverId, @RequestParam(defaultValue = "5") int limit) {
    return ResponseEntity.ok(ApiResponse.success(ratingService.getDriverReviews(driverId, limit)));
  }

  // ─── EARNINGS DASHBOARD ───

  @GetMapping("/earnings")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getEarnings(
      Authentication auth, @RequestParam(defaultValue = "daily") String period) {
    UUID driverId = UUID.fromString(auth.getName());
    List<Payment> payments = paymentRepository.findByDriverId(driverId);

    LocalDateTime now = LocalDateTime.now();
    LocalDateTime start;
    switch (period.toLowerCase()) {
      case "weekly" -> start = now.minusWeeks(1);
      case "monthly" -> start = now.minusMonths(1);
      default -> start = now.toLocalDate().atStartOfDay(); // daily
    }

    List<Payment> filtered = payments.stream()
        .filter(p -> p.getCreatedAt() != null && p.getCreatedAt().isAfter(start))
        .collect(Collectors.toList());

    double totalEarnings = filtered.stream().mapToDouble(Payment::getAmount).sum();
    int totalRides = filtered.size();

    // Daily breakdown
    Map<String, Double> dailyBreakdown = filtered.stream()
        .filter(p -> p.getCreatedAt() != null)
        .collect(Collectors.groupingBy(
            p -> p.getCreatedAt().toLocalDate().toString(),
            Collectors.summingDouble(Payment::getAmount)));

    Map<String, Object> result = new HashMap<>();
    result.put("period", period);
    result.put("totalEarnings", Math.round(totalEarnings * 100.0) / 100.0);
    result.put("totalRides", totalRides);
    result.put("dailyBreakdown", dailyBreakdown);
    result.put("averagePerRide", totalRides > 0 ? Math.round((totalEarnings / totalRides) * 100.0) / 100.0 : 0);

    return ResponseEntity.ok(ApiResponse.success(result));
  }
}
