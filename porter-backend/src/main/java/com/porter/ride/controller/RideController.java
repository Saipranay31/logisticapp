package com.porter.ride.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.ride.dto.CreateRideRequest;
import com.porter.ride.dto.RideDto;
import com.porter.ride.dto.RideRatingDto;
import com.porter.ride.entity.RideDispute;
import com.porter.ride.entity.RideRating;
import com.porter.ride.service.DisputeService;
import com.porter.ride.service.LocationTrackingService;
import com.porter.ride.service.RatingService;
import com.porter.ride.service.RideService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/rides")
@RequiredArgsConstructor
public class RideController {

  private final RideService rideService;
  private final LocationTrackingService locationTrackingService;
  private final RatingService ratingService;
  private final DisputeService disputeService;

  // ─── RIDE LIFECYCLE ───

  @PostMapping
  public ResponseEntity<ApiResponse<RideDto>> createRide(
      Authentication auth, @Valid @RequestBody CreateRideRequest request) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.createRide(userId, request)));
  }

  @GetMapping("/{rideId}")
  public ResponseEntity<ApiResponse<RideDto>> getRide(@PathVariable UUID rideId) {
    return ResponseEntity.ok(ApiResponse.success(rideService.getRide(rideId)));
  }

  @PostMapping("/{rideId}/accept")
  public ResponseEntity<ApiResponse<RideDto>> acceptRide(
      Authentication auth, @PathVariable UUID rideId) {
    UUID driverId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.acceptRide(driverId, rideId)));
  }

  @PostMapping("/{rideId}/arrive")
  public ResponseEntity<ApiResponse<RideDto>> driverArrived(
      Authentication auth, @PathVariable UUID rideId) {
    UUID driverId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.driverArrived(driverId, rideId)));
  }

  @PostMapping("/{rideId}/start")
  public ResponseEntity<ApiResponse<RideDto>> startRide(
      Authentication auth, @PathVariable UUID rideId, @RequestParam String otp) {
    UUID driverId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.verifyOtpAndStartRide(driverId, rideId, otp)));
  }

  @PostMapping("/{rideId}/complete")
  public ResponseEntity<ApiResponse<RideDto>> completeRide(
      Authentication auth, @PathVariable UUID rideId) {
    UUID driverId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.completeRide(driverId, rideId)));
  }

  // 🔴 FIX #3: New endpoints for bill confirmation flow
  @GetMapping("/{rideId}/bill")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getBill(@PathVariable UUID rideId) {
    return ResponseEntity.ok(ApiResponse.success(rideService.getBill(rideId)));
  }

  @PostMapping("/{rideId}/confirm-bill")
  public ResponseEntity<ApiResponse<RideDto>> confirmBill(
      Authentication auth, @PathVariable UUID rideId) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.confirmBill(userId, rideId)));
  }

  @PostMapping("/{rideId}/cancel")
  public ResponseEntity<ApiResponse<RideDto>> cancelRide(
      Authentication auth, @PathVariable UUID rideId) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.cancelRide(userId, rideId, "USER")));
  }

  @PostMapping("/{rideId}/payment-method")
  public ResponseEntity<ApiResponse<RideDto>> setPaymentMethod(
      Authentication auth, @PathVariable UUID rideId, @RequestParam String method) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.setPaymentMethod(userId, rideId, method)));
  }

  @PostMapping("/{rideId}/confirm-cash")
  public ResponseEntity<ApiResponse<RideDto>> confirmCashPayment(
      Authentication auth, @PathVariable UUID rideId) {
    UUID driverId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.confirmCashPayment(driverId, rideId)));
  }

  @GetMapping("/user/active")
  public ResponseEntity<ApiResponse<RideDto>> getUserActiveRide(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    RideDto active = rideService.getUserActiveRide(userId);
    return ResponseEntity.ok(ApiResponse.success(active));
  }

  @GetMapping("/driver/active")
  public ResponseEntity<ApiResponse<RideDto>> getDriverActiveRide(Authentication auth) {
    UUID driverId = UUID.fromString(auth.getName());
    RideDto active = rideService.getDriverActiveRide(driverId);
    return ResponseEntity.ok(ApiResponse.success(active));
  }

  @GetMapping("/user/history")
  public ResponseEntity<ApiResponse<List<RideDto>>> userHistory(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.getUserRideHistory(userId)));
  }

  @GetMapping("/driver/history")
  public ResponseEntity<ApiResponse<List<RideDto>>> driverHistory(Authentication auth) {
    UUID driverId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(rideService.getDriverRideHistory(driverId)));
  }

  // ─── LIVE GPS TRACKING ───

  @PostMapping("/{rideId}/location")
  public ResponseEntity<ApiResponse<Void>> updateLocation(
      Authentication auth, @PathVariable UUID rideId,
      @RequestBody Map<String, Object> location) {
    UUID driverId = UUID.fromString(auth.getName());
    locationTrackingService.updateRideLocation(rideId, driverId,
        ((Number) location.get("latitude")).doubleValue(),
        ((Number) location.get("longitude")).doubleValue(),
        location.containsKey("speed") ? ((Number) location.get("speed")).doubleValue() : null,
        location.containsKey("heading") ? ((Number) location.get("heading")).doubleValue() : null,
        location.containsKey("accuracy") ? ((Number) location.get("accuracy")).doubleValue() : null,
        location.containsKey("altitude") ? ((Number) location.get("altitude")).doubleValue() : null);
    return ResponseEntity.ok(ApiResponse.success("Location updated", null));
  }

  @GetMapping("/{rideId}/location")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getLocation(@PathVariable UUID rideId) {
    return ResponseEntity.ok(ApiResponse.success(locationTrackingService.getCurrentLocation(rideId)));
  }

  @GetMapping("/{rideId}/waypoints")
  public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getWaypoints(@PathVariable UUID rideId) {
    return ResponseEntity.ok(ApiResponse.success(locationTrackingService.getRideWaypoints(rideId)));
  }

  @GetMapping("/{rideId}/eta")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getEta(@PathVariable UUID rideId) {
    Map<String, Object> loc = locationTrackingService.getCurrentLocation(rideId);
    return ResponseEntity.ok(ApiResponse.success(loc));
  }

  // ─── RATING ───

  @PostMapping("/{rideId}/rate")
  public ResponseEntity<ApiResponse<RideRatingDto>> rateRide(
      Authentication auth, @PathVariable UUID rideId,
      @RequestBody Map<String, Object> body) {
    UUID userId = UUID.fromString(auth.getName());
    Integer rating = ((Number) body.get("rating")).intValue();
    String review = body.containsKey("review") ? (String) body.get("review") : "";

    RideRating r = ratingService.rateRide(userId, rideId, rating, review);
    RideRatingDto dto = RideRatingDto.builder()
        .id(r.getId()).rideId(r.getRideId())
        .rating(r.getRating()).reviewText(r.getReviewText())
        .createdAt(r.getCreatedAt()).build();
    return ResponseEntity.ok(ApiResponse.success(dto));
  }

  /** Driver rates the customer after ride completion. */
  @PostMapping("/{rideId}/rate-user")
  public ResponseEntity<ApiResponse<RideRatingDto>> rateUser(
      Authentication auth, @PathVariable UUID rideId,
      @RequestBody Map<String, Object> body) {
    UUID driverId = UUID.fromString(auth.getName());
    Integer rating = ((Number) body.get("rating")).intValue();
    String review = body.containsKey("review") ? (String) body.get("review") : "";

    RideRating r = ratingService.rateUser(driverId, rideId, rating, review);
    RideRatingDto dto = RideRatingDto.builder()
        .id(r.getId()).rideId(r.getRideId())
        .rating(r.getRating()).reviewText(r.getReviewText())
        .createdAt(r.getCreatedAt()).build();
    return ResponseEntity.ok(ApiResponse.success(dto));
  }

  @GetMapping("/{rideId}/rating")
  public ResponseEntity<ApiResponse<RideRatingDto>> getRideRating(@PathVariable UUID rideId) {
    RideRating r = ratingService.getRideRating(rideId).orElse(null);
    if (r == null)
      return ResponseEntity.ok(ApiResponse.success(null));
    RideRatingDto dto = RideRatingDto.builder()
        .id(r.getId()).rideId(r.getRideId())
        .rating(r.getRating()).reviewText(r.getReviewText())
        .createdAt(r.getCreatedAt()).build();
    return ResponseEntity.ok(ApiResponse.success(dto));
  }

  // ─── DISPUTE ───

  @PostMapping("/{rideId}/dispute")
  public ResponseEntity<ApiResponse<RideDispute>> createDispute(
      Authentication auth, @PathVariable UUID rideId,
      @RequestBody Map<String, String> body) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(
        disputeService.createDispute(userId, rideId,
            body.get("reason"), body.getOrDefault("description", ""))));
  }

  @GetMapping("/{rideId}/dispute")
  public ResponseEntity<ApiResponse<RideDispute>> getDispute(@PathVariable UUID rideId) {
    return ResponseEntity.ok(ApiResponse.success(
        disputeService.getDisputeByRide(rideId).orElse(null)));
  }
}
