package com.porter.ride.service;

import com.porter.ride.dto.FareConfigDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Service for managing fare configuration.
 * Provides centralized access to fare rates and validation.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FareConfigService {

  @Value("${porter.fare.base-fare:50.0}")
  private double baseFare;

  @Value("${porter.fare.per-km-rate:12.0}")
  private double perKmRate;

  @Value("${porter.fare.per-min-rate:2.0}")
  private double perMinRate;

  @Value("${porter.fare.currency:INR}")
  private String currency;

  /**
   * Get current fare configuration.
   * Returns all fare rates and vehicle multipliers.
   */
  public FareConfigDto getFareConfig() {
    Map<String, Double> multipliers = new HashMap<>();
    multipliers.put("BIKE", 1.0);
    multipliers.put("AUTO", 1.5);
    multipliers.put("MINI_TRUCK", 2.5);
    multipliers.put("TRUCK", 4.0);

    return FareConfigDto.builder()
        .baseFare(baseFare)
        .perKmRate(perKmRate)
        .perMinRate(perMinRate)
        .vehicleMultipliers(multipliers)
        .currency(currency)
        .updatedAt(LocalDateTime.now().toString())
        .build();
  }

  /**
   * Calculate fare for a given distance, duration, and vehicle type.
   */
  public double calculateFare(double distanceKm, double durationMin, String vehicleType) {
    double multiplier = getVehicleMultiplier(vehicleType);
    return (baseFare + (distanceKm * perKmRate) + (durationMin * perMinRate)) * multiplier;
  }

  /**
   * Get vehicle type multiplier.
   */
  public double getVehicleMultiplier(String vehicleType) {
    if (vehicleType == null) {
      return 1.0;
    }
    return switch (vehicleType.toUpperCase()) {
      case "BIKE" -> 1.0;
      case "AUTO" -> 1.5;
      case "MINI_TRUCK" -> 2.5;
      case "TRUCK" -> 4.0;
      default -> 1.0;
    };
  }

  /**
   * Validate fare amount within tolerance.
   * Allows 5% tolerance for time/distance variations.
   */
  public FareValidationResult validateFareAmount(double submittedFare, double actualDistance,
                                                   double actualDuration, String vehicleType) {
    double calculatedFare = calculateFare(actualDistance, actualDuration, vehicleType);
    double difference = Math.abs(submittedFare - calculatedFare);
    double tolerance = calculatedFare * 0.05; // 5% tolerance
    double percentageDiff = (difference / calculatedFare) * 100;

    boolean isValid = difference <= tolerance;

    log.info("Fare validation - Submitted: {}, Calculated: {}, Difference: {} ({}%), Tolerance: {}, Valid: {}",
        submittedFare, calculatedFare, difference, String.format("%.2f", percentageDiff), tolerance, isValid);

    return FareValidationResult.builder()
        .valid(isValid)
        .submittedFare(submittedFare)
        .calculatedFare(calculatedFare)
        .difference(difference)
        .tolerance(tolerance)
        .percentageDifference(percentageDiff)
        .build();
  }

  /**
   * DTO for fare validation results.
   */
  @lombok.Data
  @lombok.Builder
  @lombok.NoArgsConstructor
  @lombok.AllArgsConstructor
  public static class FareValidationResult {
    private boolean valid;
    private double submittedFare;
    private double calculatedFare;
    private double difference;
    private double tolerance;
    private double percentageDifference;
  }
}
