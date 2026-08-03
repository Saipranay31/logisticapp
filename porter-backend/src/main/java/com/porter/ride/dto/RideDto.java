package com.porter.ride.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RideDto {
  private UUID id;
  private UUID userId;
  private UUID driverId;
  private String status;
  private String vehicleType;

  private String pickupAddress;
  private double pickupLatitude;
  private double pickupLongitude;

  private String dropAddress;
  private double dropLatitude;
  private double dropLongitude;

  private Double estimatedDistanceKm;
  private Double estimatedDurationMin;
  private Double estimatedFare;
  private Double actualFare;
  private Double actualDistanceKm;
  private Double actualDurationMin;

  private String pickupOtp;

  private String driverName;
  private String driverPhone;
  private String driverProfileImageUrl;  // ✅ Driver profile image/avatar URL
  private Double driverRating;
  private String vehicleNumber;

  // ✅ User info (customer) for driver to see
  private String userName;
  private String userPhone;
  private Double userRating;

  // ✅ PHASE 1: Driver location for real-time tracking
  private Double driverLatitude;
  private Double driverLongitude;
  private Double estimatedEta;  // ETA in minutes

  // ✅ PHASE 2: Trip start data for dynamic pricing
  private Double tripStartLatitude;
  private Double tripStartLongitude;
  private LocalDateTime tripStartTime;

  private LocalDateTime requestedAt;
  private LocalDateTime assignedAt;
  private LocalDateTime arrivedAt;
  private LocalDateTime startedAt;
  private LocalDateTime completedAt;

  private Double cancellationFee;
  private String paymentMethod;
  private String paymentStatus;
  private String cancelledBy;
}
