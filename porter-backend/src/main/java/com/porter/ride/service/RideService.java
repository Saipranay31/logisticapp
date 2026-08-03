package com.porter.ride.service;

import com.porter.auth.entity.User;
import com.porter.auth.repository.UserRepository;
import com.porter.common.enums.RideStatus;
import com.porter.common.enums.PaymentStatus;
import com.porter.common.enums.VehicleType;
import com.porter.common.exception.BadRequestException;
import com.porter.common.exception.ResourceNotFoundException;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.entity.DriverVehicle;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.driver.repository.DriverVehicleRepository;
import com.porter.location.service.LocationService;
import com.porter.matching.service.MatchingService;
import com.porter.matching.service.RideStatusService;
import com.porter.notification.service.NotificationService;
import com.porter.payment.service.PaymentService;
import com.porter.ride.dto.CreateRideRequest;
import com.porter.ride.dto.RideDto;
import com.porter.ride.entity.Ride;
import com.porter.ride.entity.RideStatusHistory;
import com.porter.ride.repository.RideRepository;
import com.porter.ride.repository.RideRatingRepository;
import com.porter.ride.repository.RideStatusHistoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Random;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Ride service managing the complete ride lifecycle from request to completion.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RideService {

  private final RideRepository rideRepository;
  private final RideStatusHistoryRepository statusHistoryRepository;
  private final UserRepository userRepository;
  private final DriverProfileRepository driverProfileRepository;
  private final DriverVehicleRepository driverVehicleRepository;
  private final LocationService locationService;
  private final MatchingService matchingService;
  private final RideStatusService rideStatusService; // ✅ ADD THIS
  private final PaymentService paymentService;
  private final NotificationService notificationService;
  private final SimpMessagingTemplate messagingTemplate;
  private final LocationTrackingService locationTrackingService;
  private final FareConfigService fareConfigService;
  private final RideRatingRepository rideRatingRepository;

  private final Random random = new Random();

  /**
   * Create a new ride request.
   */
  @Transactional
  public RideDto createRide(UUID userId, CreateRideRequest request) {
    // Calculate distance and fare estimate
    double distance = locationService.calculateDistance(
        request.getPickupLatitude(), request.getPickupLongitude(),
        request.getDropLatitude(), request.getDropLongitude());
    double duration = locationService.estimateEta(distance);
    double fare = calculateFare(distance, duration, request.getVehicleType());

    // ✅ FIX: Generate OTP properly (0000-9999)
    String pickupOtp = String.format("%04d", random.nextInt(10000));

    Ride ride = Ride.builder()
        .userId(userId)
        .vehicleType(request.getVehicleType())
        .status(RideStatus.REQUESTED)
        .pickupAddress(request.getPickupAddress())
        .pickupLatitude(request.getPickupLatitude())
        .pickupLongitude(request.getPickupLongitude())
        .dropAddress(request.getDropAddress())
        .dropLatitude(request.getDropLatitude())
        .dropLongitude(request.getDropLongitude())
        .estimatedDistanceKm(Math.round(distance * 100.0) / 100.0)
        .estimatedDurationMin(Math.round(duration * 100.0) / 100.0)
        .estimatedFare(Math.round(fare * 100.0) / 100.0)
        .pickupOtp(pickupOtp)
        .requestedAt(LocalDateTime.now())
        .build();

    ride = rideRepository.save(ride);
    log.info("🚀 RIDE CREATED AND SAVED: rideId={}, userId={}, vehicleType={}", ride.getId(), userId, ride.getVehicleType());

    recordStatusChange(ride.getId(), null, RideStatus.REQUESTED, userId);
    log.info("📝 Status history recorded for ride {}", ride.getId());

    log.info("Ride {} created by user {}", ride.getId(), userId);

    // ✅ CRITICAL FIX: Update status to SEARCHING SYNCHRONOUSLY BEFORE async search
    // This prevents race condition where driver accepts while status is still REQUESTED
    // Update happens in same transaction, so status is persisted BEFORE findDriverForRide runs
    UUID rideId = ride.getId();
    rideRepository.updateRideStatus(rideId, RideStatus.SEARCHING);
    recordStatusChange(rideId, RideStatus.REQUESTED, RideStatus.SEARCHING, userId);
    log.info("🔄 SYNCHRONOUS: Ride status transitioned to SEARCHING before async search: rideId={}", rideId);

    // Trigger matching asynchronously (now ride is already in SEARCHING state)
    log.info("🔍 CALLING findDriverForRide with rideId={}", rideId);
    matchingService.findDriverForRide(ride);
    log.info("✅ findDriverForRide completed for rideId={}", rideId);

    // ✅ Fetch fresh ride data with updated status to return to client
    Ride updatedRide = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    RideDto dto = mapToDto(updatedRide);
    log.info("📤 RETURNING RideDto: rideId={}, status={}", dto.getId(), dto.getStatus());
    return dto;
  }

  /**
   * Driver accepts a ride. Uses pessimistic lock to prevent concurrent
   * acceptance.
   */
  @Transactional
  public RideDto acceptRide(UUID driverId, UUID rideId) {
    // Pessimistic lock prevents multiple drivers accepting the same ride
    Ride ride = rideRepository.findByIdForUpdate(rideId)
        .orElseThrow(() -> new com.porter.common.exception.ResourceNotFoundException("Ride not found"));

    RideStatusValidator.validateTransition(ride.getStatus(), RideStatus.ASSIGNED);

    // Concurrency-safe: check and assign atomically
    ride.setDriverId(driverId);
    ride.setStatus(RideStatus.ASSIGNED);
    ride.setAssignedAt(LocalDateTime.now());
    ride = rideRepository.save(ride);

    recordStatusChange(rideId, RideStatus.SEARCHING, RideStatus.ASSIGNED, driverId);

    // ✅ Notify user via FCM + WebSocket
    notificationService.sendNotification(ride.getUserId(), "Driver Assigned",
        "Your driver is on the way!", "RIDE_UPDATE");

    // ✅ CRITICAL: Broadcast full ride details to user via WebSocket
    RideDto dto = mapToDto(ride);
    log.info("📡 BROADCASTING RIDE ASSIGNMENT: Sending to /topic/user/{}/ride with driverId={}, driverName={}, driverRating={}",
        ride.getUserId(), dto.getDriverId(), dto.getDriverName(), dto.getDriverRating());
    broadcastRideUpdate(ride);

    log.info("✅ RIDE ACCEPTED: Ride {} accepted by driver {}", rideId, driverId);
    return dto;
  }

  /**
   * Driver marks arrival at pickup point.
   */
  @Transactional
  public RideDto driverArrived(UUID driverId, UUID rideId) {
    Ride ride = getRideOrThrow(rideId);
    validateDriverOwnership(ride, driverId);

    if (ride.getStatus() != RideStatus.ASSIGNED) {
      throw new BadRequestException("Invalid status transition");
    }

    ride.setStatus(RideStatus.ARRIVED);
    ride.setArrivedAt(LocalDateTime.now());
    ride = rideRepository.save(ride);

    recordStatusChange(rideId, RideStatus.ASSIGNED, RideStatus.ARRIVED, driverId);
    // Fix 7: OTP is NOT included in the push notification body (visible in the
    // notification shade before the app is opened). The OTP is delivered securely
    // via the WebSocket RideDto broadcast below — only readable inside the app.
    notificationService.sendNotification(ride.getUserId(), "Driver Arrived",
        "Your driver has arrived at the pickup point. Please share your OTP.", "RIDE_UPDATE");
    broadcastRideUpdate(ride);

    return mapToDto(ride);
  }

  /**
   * Verify pickup OTP and start ride.
   * ✅ PHASE 2: Record trip start location for dynamic pricing
   * ✅ FIX: Proper OTP validation with logging and null checks
   */
  @Transactional
  public RideDto verifyOtpAndStartRide(UUID driverId, UUID rideId, String otp) {
    Ride ride = getRideOrThrow(rideId);
    validateDriverOwnership(ride, driverId);

    if (ride.getStatus() != RideStatus.ARRIVED) {
      throw new BadRequestException("Driver must arrive before starting ride");
    }

    // ✅ FIX: Null check and trimming for OTP validation
    if (ride.getPickupOtp() == null) {
      log.error("❌ ERROR: Pickup OTP is NULL for ride {}", rideId);
      throw new BadRequestException("No OTP generated for this ride");
    }

    // Trim whitespace from both OTP and received input
    String storedOtp = ride.getPickupOtp().trim();
    String receivedOtp = otp != null ? otp.trim() : "";

    log.info("🔐 OTP Verification Attempt - RideId: {}, StoredOTP: '{}', ReceivedOTP: '{}', Match: {}",
        rideId, storedOtp, receivedOtp, storedOtp.equals(receivedOtp));

    if (!storedOtp.equals(receivedOtp)) {
      log.warn("⚠️ OTP MISMATCH - RideId: {}, Expected: '{}', Got: '{}', DriverId: {}",
          rideId, storedOtp, receivedOtp, driverId);
      throw new BadRequestException("Invalid OTP. Please enter the correct OTP provided to the customer.");
    }

    log.info("✅ OTP VERIFIED SUCCESSFULLY - RideId: {}, DriverId: {}", rideId, driverId);

    ride.setStatus(RideStatus.IN_PROGRESS);
    ride.setStartedAt(LocalDateTime.now());

    // ✅ PHASE 2: Record trip start location for dynamic pricing
    ride.setTripStartLatitude(ride.getDriverLatitude());
    ride.setTripStartLongitude(ride.getDriverLongitude());
    ride.setTripStartTime(LocalDateTime.now());

    ride = rideRepository.save(ride);

    recordStatusChange(rideId, RideStatus.ARRIVED, RideStatus.IN_PROGRESS, driverId);
    notificationService.sendNotification(ride.getUserId(), "Ride Started",
        "Your ride has started!", "RIDE_UPDATE");
    broadcastRideUpdate(ride);

    return mapToDto(ride);
  }

  /**
   * Complete ride and set payment status to PENDING for bill confirmation.
   * Payment is deferred until user confirms the bill.
   */
  @Transactional
  public RideDto completeRide(UUID driverId, UUID rideId) {
    Ride ride = getRideOrThrow(rideId);
    validateDriverOwnership(ride, driverId);

    if (ride.getStatus() != RideStatus.IN_PROGRESS) {
      throw new BadRequestException("Ride must be in progress to complete");
    }

    // Calculate actual distance from GPS tracking data
    double actualDistance = locationTrackingService.calculateActualDistance(rideId);
    double actualDuration = ride.getStartedAt() != null
        ? java.time.Duration.between(ride.getStartedAt(), LocalDateTime.now()).toMinutes()
        : ride.getEstimatedDurationMin();

    // Use GPS distance if available, otherwise fall back to estimated
    ride.setActualDistanceKm(actualDistance > 0 ? actualDistance : ride.getEstimatedDistanceKm());
    ride.setActualDurationMin(actualDuration);

    // ✅ FIX: Use estimatedFare as the agreed-upon fare shown to user at booking
    // The estimatedFare was calculated from map distance/duration and is the quoted price.
    // Only charge more if actual distance/time significantly exceeds estimate.
    double calculatedFare = calculateFare(ride.getActualDistanceKm(), ride.getActualDurationMin(), ride.getVehicleType());
    ride.setActualFare(Math.max(ride.getEstimatedFare(), calculatedFare));

    ride.setStatus(RideStatus.COMPLETED);
    ride.setCompletedAt(LocalDateTime.now());
    ride.setPaymentStatus(PaymentStatus.PENDING); // 🔴 FIX #3: Defer payment until bill confirmation
    ride = rideRepository.save(ride);

    recordStatusChange(rideId, RideStatus.IN_PROGRESS, RideStatus.COMPLETED, driverId);

    // 🔴 FIX #3: Do NOT process payment here - wait for bill confirmation
    // paymentService.processPayment(ride);  // ❌ Removed

    // Update driver stats
    DriverProfile driverProfile = driverProfileRepository.findByUserId(driverId).orElse(null);
    if (driverProfile != null) {
      driverProfile.setTotalRides(driverProfile.getTotalRides() + 1);
      driverProfileRepository.save(driverProfile);
    }

    notificationService.sendNotification(ride.getUserId(), "Ride Completed",
        "Your ride is complete. Please confirm the bill.", "RIDE_UPDATE");
    broadcastRideUpdate(ride);

    log.info("Ride {} completed - payment pending bill confirmation", rideId);
    return mapToDto(ride);
  }

  /**
   * Cancel a ride.
   */
  @Transactional
  public RideDto cancelRide(UUID cancelledById, UUID rideId, String cancelledBy) {
    Ride ride = getRideOrThrow(rideId);

    if (ride.getStatus() == RideStatus.COMPLETED || ride.getStatus() == RideStatus.CANCELLED) {
      throw new BadRequestException("Cannot cancel a completed or already cancelled ride");
    }

    // Calculate cancellation fee based on status
    double cancellationFee = 0.0;
    if (ride.getStatus() == RideStatus.ASSIGNED) {
      // Driver assigned but not arrived → flat ₹50
      cancellationFee = 50.0;
      log.info("💰 Cancellation fee ₹50 (driver assigned) for ride {}", rideId);
    } else if (ride.getStatus() == RideStatus.ARRIVED || ride.getStatus() == RideStatus.IN_PROGRESS) {
      // Driver arrived or in progress → distance-based fee
      if (ride.getDriverLatitude() != null && ride.getDriverLongitude() != null) {
        double distKm = locationService.calculateDistance(
            ride.getDriverLatitude(), ride.getDriverLongitude(),
            ride.getPickupLatitude(), ride.getPickupLongitude());
        cancellationFee = Math.max(50.0, distKm * 12.0); // at least ₹50, or ₹12/km
      } else {
        cancellationFee = 50.0;
      }
      log.info("💰 Cancellation fee ₹{} (driver arrived/in-progress) for ride {}", cancellationFee, rideId);
    }
    // SEARCHING / REQUESTED → free cancellation

    ride.setStatus(RideStatus.CANCELLED);
    ride.setCancelledAt(LocalDateTime.now());
    ride.setCancelledBy(cancelledBy);
    ride.setCancellationFee(cancellationFee > 0 ? cancellationFee : null);
    ride = rideRepository.save(ride);

    recordStatusChange(rideId, ride.getStatus(), RideStatus.CANCELLED, cancelledById);
    broadcastRideUpdate(ride);

    // Notify driver if assigned
    if (ride.getDriverId() != null) {
      notificationService.sendNotification(ride.getDriverId(), "Ride Cancelled",
          "The ride has been cancelled by the user." + (cancellationFee > 0 ? " Cancellation fee: ₹" + cancellationFee : ""), "RIDE_UPDATE");
    }

    log.info("Ride {} cancelled by {} with fee ₹{}", rideId, cancelledBy, cancellationFee);
    return mapToDto(ride);
  }

  /**
   * Set payment method for a ride (CASH or ONLINE).
   */
  @Transactional
  public RideDto setPaymentMethod(UUID userId, UUID rideId, String method) {
    Ride ride = getRideOrThrow(rideId);
    ride.setPaymentMethod(method);
    ride = rideRepository.save(ride);

    if ("CASH".equals(method) && ride.getDriverId() != null) {
      notificationService.sendNotification(ride.getDriverId(), "Cash Payment",
          "User selected cash payment. Collect ₹" + (ride.getActualFare() != null ? ride.getActualFare() : ride.getEstimatedFare()), "PAYMENT_UPDATE");
    }

    broadcastRideUpdate(ride);
    return mapToDto(ride);
  }

  /**
   * Driver confirms cash has been received.
   */
  @Transactional
  public RideDto confirmCashPayment(UUID driverId, UUID rideId) {
    Ride ride = getRideOrThrow(rideId);
    validateDriverOwnership(ride, driverId);

    ride.setPaymentStatus(PaymentStatus.COMPLETED);
    ride = rideRepository.save(ride);

    notificationService.sendNotification(ride.getUserId(), "Payment Confirmed",
        "Cash payment of ₹" + ride.getActualFare() + " confirmed by driver.", "PAYMENT_UPDATE");
    broadcastRideUpdate(ride);

    log.info("Cash payment confirmed for ride {} by driver {}", rideId, driverId);
    return mapToDto(ride);
  }

  public RideDto getRide(UUID rideId) {
    return mapToDto(getRideOrThrow(rideId));
  }

  public List<RideDto> getUserRideHistory(UUID userId) {
    return rideRepository.findByUserIdOrderByCreatedAtDesc(userId)
        .stream().map(this::mapToDto).collect(Collectors.toList());
  }

  public List<RideDto> getDriverRideHistory(UUID driverId) {
    return rideRepository.findByDriverIdOrderByCreatedAtDesc(driverId)
        .stream().map(this::mapToDto).collect(Collectors.toList());
  }

  public List<RideDto> getActiveRides() {
    return rideRepository.findByStatusIn(List.of(
        RideStatus.REQUESTED, RideStatus.SEARCHING, RideStatus.ASSIGNED,
        RideStatus.ARRIVED, RideStatus.IN_PROGRESS)).stream().map(this::mapToDto).collect(Collectors.toList());
  }

  public List<RideDto> getAllRidesByStatus(String status) {
    List<Ride> rides;
    if (status == null || status.equalsIgnoreCase("ALL")) {
      rides = rideRepository.findAll();
    } else if (status.equalsIgnoreCase("ACTIVE")) {
      rides = rideRepository.findByStatusIn(List.of(
          RideStatus.REQUESTED, RideStatus.SEARCHING, RideStatus.ASSIGNED,
          RideStatus.ARRIVED, RideStatus.IN_PROGRESS));
    } else {
      rides = rideRepository.findByStatus(RideStatus.valueOf(status.toUpperCase()));
    }
    return rides.stream()
        .sorted(java.util.Comparator.comparing(
            r -> r.getRequestedAt() != null ? r.getRequestedAt() : java.time.LocalDateTime.MIN,
            java.util.Comparator.reverseOrder()))
        .map(this::mapToDto)
        .collect(Collectors.toList());
  }

  /**
   * Get the user's current active ride (if any).
   * Excludes COMPLETED rides that already had their bill/payment handled.
   */
  public RideDto getUserActiveRide(UUID userId) {
    List<Ride> active = rideRepository.findByUserIdAndStatusIn(userId, List.of(
        RideStatus.SEARCHING, RideStatus.ASSIGNED,
        RideStatus.ARRIVED, RideStatus.IN_PROGRESS, RideStatus.COMPLETED));
    // Filter out fully-finished COMPLETED rides (payment already done)
    active = active.stream()
        .filter(r -> r.getStatus() != RideStatus.COMPLETED ||
                     r.getPaymentStatus() == PaymentStatus.PENDING)
        .collect(java.util.stream.Collectors.toList());
    if (active.isEmpty()) return null;
    return mapToDto(active.get(0));
  }

  /**
   * Get the driver's current active ride (if any).
   * Excludes COMPLETED rides that already had their payment confirmed.
   */
  public RideDto getDriverActiveRide(UUID driverId) {
    List<Ride> active = rideRepository.findByDriverIdAndStatusIn(driverId, List.of(
        RideStatus.ASSIGNED, RideStatus.ARRIVED, RideStatus.IN_PROGRESS, RideStatus.COMPLETED));
    // Filter out fully-finished COMPLETED rides (payment already done)
    active = active.stream()
        .filter(r -> r.getStatus() != RideStatus.COMPLETED ||
                     r.getPaymentStatus() == PaymentStatus.PENDING)
        .collect(java.util.stream.Collectors.toList());
    if (active.isEmpty()) return null;
    return mapToDto(active.get(0));
  }

  /**
   * Get bill details for a completed ride.
   * 🔴 FIX #3: New endpoint for bill confirmation flow
   */
  public Map<String, Object> getBill(UUID rideId) {
    Ride ride = getRideOrThrow(rideId);

    if (ride.getStatus() != RideStatus.COMPLETED) {
      throw new BadRequestException("Bill available only after ride completion");
    }

    Map<String, Object> bill = new HashMap<>();
    bill.put("rideId", ride.getId());
    bill.put("userId", ride.getUserId());
    bill.put("driverId", ride.getDriverId());
    bill.put("pickupAddress", ride.getPickupAddress());
    bill.put("dropAddress", ride.getDropAddress());
    bill.put("actualDistanceKm", ride.getActualDistanceKm());
    bill.put("actualDurationMin", ride.getActualDurationMin());
    bill.put("actualFare", ride.getActualFare());
    bill.put("paymentStatus", ride.getPaymentStatus());
    bill.put("completedAt", ride.getCompletedAt());

    // Add driver info
    if (ride.getDriverId() != null) {
      userRepository.findById(ride.getDriverId()).ifPresent(driver -> {
        bill.put("driverName", driver.getFullName());
        bill.put("driverPhone", driver.getPhone());
      });
    }

    return bill;
  }

  /**
   * Confirm bill and trigger payment processing asynchronously.
   * 🔴 FIX #3: User confirms bill, then payment is processed
   */
  @Transactional
  public RideDto confirmBill(UUID userId, UUID rideId) {
    Ride ride = getRideOrThrow(rideId);

    // Validate that this is the user's ride
    if (!userId.equals(ride.getUserId())) {
      throw new BadRequestException("You are not the user for this ride");
    }

    // Validate that ride is completed and payment is pending
    if (ride.getStatus() != RideStatus.COMPLETED) {
      throw new BadRequestException("Ride is not completed");
    }

    if (ride.getPaymentStatus() != PaymentStatus.PENDING) {
      throw new BadRequestException("Bill is not pending confirmation");
    }

    // Mark bill as confirmed
    ride.setPaymentStatus(PaymentStatus.CONFIRMED);
    ride = rideRepository.save(ride);

    // Process payment asynchronously (non-blocking)
    paymentService.processPaymentAsync(ride);

    notificationService.sendNotification(ride.getUserId(), "Bill Confirmed",
        "Payment of ₹" + ride.getActualFare() + " is being processed", "PAYMENT_UPDATE");
    broadcastRideUpdate(ride);

    log.info("Bill confirmed for ride {} - payment processing initiated", rideId);
    return mapToDto(ride);
  }

  // --- Helper Methods ---

  private double calculateFare(double distanceKm, double durationMin, String vehicleType) {
    return fareConfigService.calculateFare(distanceKm, durationMin, vehicleType);
  }

  private double getVehicleMultiplier(String vehicleType) {
    return fareConfigService.getVehicleMultiplier(vehicleType);
  }

  private Ride getRideOrThrow(UUID rideId) {
    return rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
  }

  private void validateDriverOwnership(Ride ride, UUID driverId) {
    if (!driverId.equals(ride.getDriverId())) {
      throw new BadRequestException("You are not assigned to this ride");
    }
  }

  private void recordStatusChange(UUID rideId, RideStatus from, RideStatus to, UUID changedBy) {
    RideStatusHistory history = RideStatusHistory.builder()
        .rideId(rideId)
        .fromStatus(from != null ? from.name() : null)
        .toStatus(to.name())
        .changedBy(changedBy)
        .changedAt(LocalDateTime.now())
        .build();
    statusHistoryRepository.save(history);
  }

  private void broadcastRideUpdate(Ride ride) {
    RideDto dto = mapToDto(ride);
    log.info("📤 BROADCAST DTO: driverId={}, driverName={}, driverPhone={}, driverProfileImageUrl={}, driverRating={}",
        dto.getDriverId(), dto.getDriverName(), dto.getDriverPhone(), dto.getDriverProfileImageUrl(), dto.getDriverRating());
    messagingTemplate.convertAndSend("/topic/ride/" + ride.getId(), dto);
    if (ride.getUserId() != null) {
      messagingTemplate.convertAndSend("/topic/user/" + ride.getUserId() + "/ride", dto);
    }
    if (ride.getDriverId() != null) {
      messagingTemplate.convertAndSend("/topic/driver/" + ride.getDriverId() + "/ride", dto);
    }
  }

  private RideDto mapToDto(Ride ride) {
    // ✅ FIX: Fetch current driver location from LocationTrackingService for active rides
    Double driverLatitude = ride.getDriverLatitude();
    Double driverLongitude = ride.getDriverLongitude();
    Double estimatedEta = calculateEtaToDestination(ride);

    if ((ride.getStatus() == RideStatus.ASSIGNED ||
         ride.getStatus() == RideStatus.ARRIVED ||
         ride.getStatus() == RideStatus.IN_PROGRESS) &&
        ride.getId() != null) {
      try {
        // Try 1: Location from ride tracking database (REST API path)
        Map<String, Object> currentLocation = locationTrackingService.getCurrentLocation(ride.getId());
        if ((Boolean) currentLocation.getOrDefault("available", false)) {
          driverLatitude = ((Number) currentLocation.get("latitude")).doubleValue();
          driverLongitude = ((Number) currentLocation.get("longitude")).doubleValue();
          estimatedEta = ((Number) currentLocation.get("estimatedEta")).doubleValue();
          log.debug("📍 Using ride tracking location for ride {}: ({}, {})", ride.getId(), driverLatitude, driverLongitude);
        } else if (ride.getDriverId() != null) {
          // Try 2: Location from Redis GEO set (WebSocket path) - keyed by driverId
          Map<String, Double> geoLocation = locationService.getDriverLocation(ride.getDriverId().toString());
          if (!geoLocation.isEmpty()) {
            driverLatitude = geoLocation.get("latitude");
            driverLongitude = geoLocation.get("longitude");
            log.info("📍 Using Redis GEO location for driver {}: ({}, {})", ride.getDriverId(), driverLatitude, driverLongitude);
          }
        }
      } catch (Exception e) {
        log.warn("⚠️ Could not fetch current driver location for ride {}: {}", ride.getId(), e.getMessage());
        // Fallback to stored values
      }
    }

    // ✅ FIX: Ensure driverLatitude and driverLongitude are always sent in response,
    // even if they're null initially - the user app needs these fields to display the map
    RideDto dto = RideDto.builder()
        .id(ride.getId())
        .userId(ride.getUserId())
        .driverId(ride.getDriverId())
        .status(ride.getStatus().name())
        .vehicleType(ride.getVehicleType())
        .pickupAddress(ride.getPickupAddress())
        .pickupLatitude(ride.getPickupLatitude())
        .pickupLongitude(ride.getPickupLongitude())
        .dropAddress(ride.getDropAddress())
        .dropLatitude(ride.getDropLatitude())
        .dropLongitude(ride.getDropLongitude())
        .estimatedDistanceKm(ride.getEstimatedDistanceKm())
        .estimatedDurationMin(ride.getEstimatedDurationMin())
        .estimatedFare(ride.getEstimatedFare())
        .actualFare(ride.getActualFare())
        .actualDistanceKm(ride.getActualDistanceKm())
        .actualDurationMin(ride.getActualDurationMin())
        .pickupOtp(ride.getPickupOtp())
        // ✅ FIX: Use current driver location from LocationTrackingService
        .driverLatitude(driverLatitude)
        .driverLongitude(driverLongitude)
        // ✅ FIX: Use updated ETA from current location
        .estimatedEta(estimatedEta)
        // ✅ PHASE 2: Add trip start data for dynamic pricing
        .tripStartLatitude(ride.getTripStartLatitude())
        .tripStartLongitude(ride.getTripStartLongitude())
        .tripStartTime(ride.getTripStartTime())
        .requestedAt(ride.getRequestedAt())
        .assignedAt(ride.getAssignedAt())
        .arrivedAt(ride.getArrivedAt())
        .startedAt(ride.getStartedAt())
        .completedAt(ride.getCompletedAt())
        .cancellationFee(ride.getCancellationFee())
        .paymentMethod(ride.getPaymentMethod())
        .paymentStatus(ride.getPaymentStatus() != null ? ride.getPaymentStatus().name() : null)
        .cancelledBy(ride.getCancelledBy())
        .build();

    // Enrich with driver info if assigned
    if (ride.getDriverId() != null) {
      userRepository.findById(ride.getDriverId()).ifPresent(driver -> {
        dto.setDriverName(driver.getFullName());
        dto.setDriverPhone(driver.getPhone());
        log.info("✅ DRIVER INFO: driverId={}, name={}, phone={}", ride.getDriverId(), driver.getFullName(), driver.getPhone());
      });
      driverProfileRepository.findByUserId(ride.getDriverId()).ifPresent(profile -> {
        dto.setDriverRating(profile.getRating());
        // ✅ FIX: Return RELATIVE path - frontend converts to absolute URL with correct IP
        String avatarUrl = profile.getAvatarUrl();
        dto.setDriverProfileImageUrl(avatarUrl);  // ✅ Set driver profile image as relative path (e.g., /api/files/drivers/uuid.jpg)
        log.info("✅ DRIVER PROFILE: rating={}, avatarUrl={}, (frontend converts to absolute with AppConfig)", profile.getRating(), avatarUrl);
        driverVehicleRepository.findByDriverProfileIdAndIsActive(profile.getId(), true)
            .ifPresent(v -> {
              dto.setVehicleNumber(v.getVehicleNumber());
              log.info("✅ DRIVER VEHICLE: vehicleNumber={}", v.getVehicleNumber());
            });
      });
    }

    // Enrich with user (customer) info
    if (ride.getUserId() != null) {
      userRepository.findById(ride.getUserId()).ifPresent(user -> {
        dto.setUserName(user.getFullName());
        dto.setUserPhone(user.getPhone());
      });
      Double avgUserRating = rideRatingRepository.getAverageRatingForDriver(ride.getUserId());
      dto.setUserRating(avgUserRating != null ? Math.round(avgUserRating * 10.0) / 10.0 : null);
    }

    // ✅ FIX: Log driver location info for debugging
    if (ride.getStatus() != RideStatus.REQUESTED && ride.getStatus() != RideStatus.SEARCHING) {
      log.debug("🚗 RideDto mapped - RideId: {}, DriverId: {}, DriverLocation: ({}, {}), Status: {}",
          ride.getId(), ride.getDriverId(), driverLatitude, driverLongitude, ride.getStatus());
    }

    return dto;
  }

  // ✅ PHASE 1: Calculate ETA from driver current location to drop
  private Double calculateEtaToDestination(Ride ride) {
    if (ride.getDriverLatitude() == null || ride.getDriverLongitude() == null) {
      return ride.getEstimatedDurationMin();
    }

    double distance = locationService.calculateDistance(
      ride.getDriverLatitude(), ride.getDriverLongitude(),
      ride.getDropLatitude(), ride.getDropLongitude()
    );

    return locationService.estimateEta(distance);
  }
}
