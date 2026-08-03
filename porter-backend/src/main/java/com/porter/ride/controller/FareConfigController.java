package com.porter.ride.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.ride.dto.FareConfigDto;
import com.porter.ride.service.FareConfigService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Controller for fare configuration endpoints.
 * Provides fare rates and validation to frontend applications.
 */
@RestController
@RequestMapping("/api/fares")
@RequiredArgsConstructor
@Slf4j
public class FareConfigController {

  private final FareConfigService fareConfigService;

  /**
   * Get current fare configuration.
   * Returns all rates, multipliers, and pricing information.
   */
  @GetMapping("/config")
  public ResponseEntity<ApiResponse<FareConfigDto>> getFareConfig() {
    log.info("Fetching fare configuration");
    FareConfigDto config = fareConfigService.getFareConfig();
    return ResponseEntity.ok(ApiResponse.success(config));
  }

  /**
   * Validate fare amount for a completed ride.
   * Checks if submitted fare matches calculated fare within tolerance.
   * POST body: { submittedFare: double, distance: double, duration: double, vehicleType: String }
   */
  @PostMapping("/{rideId}/validate")
  public ResponseEntity<ApiResponse<Map<String, Object>>> validateFare(
      @PathVariable UUID rideId,
      @RequestBody Map<String, Object> validationRequest) {
    try {
      double submittedFare = ((Number) validationRequest.get("submittedFare")).doubleValue();
      double distance = ((Number) validationRequest.get("distance")).doubleValue();
      double duration = ((Number) validationRequest.get("duration")).doubleValue();
      String vehicleType = (String) validationRequest.get("vehicleType");

      FareConfigService.FareValidationResult result =
          fareConfigService.validateFareAmount(submittedFare, distance, duration, vehicleType);

      Map<String, Object> response = new HashMap<>();
      response.put("valid", result.isValid());
      response.put("submittedFare", result.getSubmittedFare());
      response.put("calculatedFare", result.getCalculatedFare());
      response.put("difference", result.getDifference());
      response.put("tolerance", result.getTolerance());
      response.put("percentageDifference", String.format("%.2f%%", result.getPercentageDifference()));

      log.info("Fare validation for ride {} - Valid: {}", rideId, result.isValid());
      return ResponseEntity.ok(ApiResponse.success(response));
    } catch (Exception e) {
      log.error("Error validating fare for ride {}: {}", rideId, e.getMessage());
      return ResponseEntity.badRequest()
          .body(ApiResponse.error("Invalid validation request: " + e.getMessage()));
    }
  }
}
