package com.porter.ride.entity;

import com.porter.common.entity.BaseEntity;
import com.porter.common.enums.RideStatus;
import com.porter.common.enums.PaymentStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "rides")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Ride extends BaseEntity {

  @Version
  private Long version;

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(name = "driver_id")
  private UUID driverId;

  @Column(name = "vehicle_type", nullable = false)
  private String vehicleType;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private RideStatus status = RideStatus.REQUESTED;

  @Enumerated(EnumType.STRING)
  @Column(name = "payment_status")
  private PaymentStatus paymentStatus = PaymentStatus.PENDING;  // PENDING, CONFIRMED, COMPLETED, FAILED

  // Pickup
  @Column(name = "pickup_address", nullable = false)
  private String pickupAddress;

  @Column(name = "pickup_latitude", nullable = false)
  private double pickupLatitude;

  @Column(name = "pickup_longitude", nullable = false)
  private double pickupLongitude;

  // Drop
  @Column(name = "drop_address", nullable = false)
  private String dropAddress;

  @Column(name = "drop_latitude", nullable = false)
  private double dropLatitude;

  @Column(name = "drop_longitude", nullable = false)
  private double dropLongitude;

  // Fare estimates
  @Column(name = "estimated_distance_km")
  private Double estimatedDistanceKm;

  @Column(name = "estimated_duration_min")
  private Double estimatedDurationMin;

  @Column(name = "estimated_fare")
  private Double estimatedFare;

  @Column(name = "actual_distance_km")
  private Double actualDistanceKm;

  @Column(name = "actual_duration_min")
  private Double actualDurationMin;

  @Column(name = "actual_fare")
  private Double actualFare;

  // OTP
  @Column(name = "pickup_otp")
  private String pickupOtp;

  // ✅ PHASE 1: Driver's current location for real-time tracking
  @Column(name = "driver_latitude")
  private Double driverLatitude;

  @Column(name = "driver_longitude")
  private Double driverLongitude;

  // ✅ PHASE 2: Trip start location for dynamic pricing
  @Column(name = "trip_start_latitude")
  private Double tripStartLatitude;

  @Column(name = "trip_start_longitude")
  private Double tripStartLongitude;

  @Column(name = "trip_start_time")
  private LocalDateTime tripStartTime;

  // Timestamps
  @Column(name = "requested_at")
  private LocalDateTime requestedAt;

  @Column(name = "assigned_at")
  private LocalDateTime assignedAt;

  @Column(name = "arrived_at")
  private LocalDateTime arrivedAt;

  @Column(name = "started_at")
  private LocalDateTime startedAt;

  @Column(name = "completed_at")
  private LocalDateTime completedAt;

  @Column(name = "cancelled_at")
  private LocalDateTime cancelledAt;

  @Column(name = "cancelled_by")
  private String cancelledBy;

  @Column(name = "cancellation_fee")
  private Double cancellationFee;

  @Column(name = "payment_method")
  private String paymentMethod; // CASH or ONLINE
}
