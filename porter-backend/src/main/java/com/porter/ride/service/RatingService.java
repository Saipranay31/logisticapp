package com.porter.ride.service;

import com.porter.common.enums.RideStatus;
import com.porter.common.exception.BadRequestException;
import com.porter.common.exception.ResourceNotFoundException;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.financial.service.FinancialService;
import com.porter.ride.entity.Ride;
import com.porter.ride.entity.RideRating;
import com.porter.ride.repository.RideRatingRepository;
import com.porter.ride.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class RatingService {

  private final RideRatingRepository ratingRepository;
  private final RideRepository rideRepository;
  private final DriverProfileRepository driverProfileRepository;
  private final FinancialService financialService;

  @Transactional
  public RideRating rateRide(UUID userId, UUID rideId, Integer rating, String reviewText) {
    if (rating < 1 || rating > 5) {
      throw new BadRequestException("Rating must be between 1 and 5");
    }

    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    if (ride.getStatus() != RideStatus.COMPLETED) {
      throw new BadRequestException("Can only rate completed rides");
    }

    if (!ride.getUserId().equals(userId)) {
      throw new BadRequestException("You cannot rate this ride");
    }

    if (ratingRepository.findByRideIdAndRaterId(rideId, userId).isPresent()) {
      throw new BadRequestException("You have already rated this ride");
    }

    RideRating rideRating = RideRating.builder()
        .rideId(rideId)
        .raterId(userId)
        .rateeId(ride.getDriverId())
        .rating(rating)
        .reviewText(reviewText)
        .build();

    rideRating = ratingRepository.save(rideRating);

    // Update driver's average rating
    updateDriverRating(ride.getDriverId());

    log.info("Ride {} rated {} stars by user {}", rideId, rating, userId);
    return rideRating;
  }

  /** Driver rates the customer after ride completion. */
  @Transactional
  public RideRating rateUser(UUID driverId, UUID rideId, Integer rating, String reviewText) {
    if (rating < 1 || rating > 5) {
      throw new BadRequestException("Rating must be between 1 and 5");
    }

    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    if (ride.getStatus() != RideStatus.COMPLETED) {
      throw new BadRequestException("Can only rate completed rides");
    }

    if (!driverId.equals(ride.getDriverId())) {
      throw new BadRequestException("You were not the driver for this ride");
    }

    if (ratingRepository.findByRideIdAndRaterId(rideId, driverId).isPresent()) {
      throw new BadRequestException("You have already rated this customer");
    }

    RideRating rideRating = RideRating.builder()
        .rideId(rideId)
        .raterId(driverId)
        .rateeId(ride.getUserId())
        .rating(rating)
        .reviewText(reviewText)
        .build();

    rideRating = ratingRepository.save(rideRating);
    log.info("Ride {} rated {} stars for customer by driver {}", rideId, rating, driverId);
    return rideRating;
  }

  public Optional<RideRating> getRideRating(UUID rideId) {
    return ratingRepository.findByRideId(rideId);
  }

  public Map<String, Object> getDriverRatings(UUID driverId) {
    Double avg = ratingRepository.getAverageRatingForDriver(driverId);
    Long total = ratingRepository.getTotalRatingsForDriver(driverId);

    // Get driver's total trips by counting all rides (more reliable)
    long totalTrips = rideRepository.countByDriverId(driverId);

    log.info("🔍 PERFORMANCE METRICS: driverId={}, totalTrips={}, avgRating={}, totalRatings={}",
        driverId, totalTrips, avg, total);

    // Calculate acceptance and cancellation rates
    long completedRides = rideRepository.countByDriverIdAndStatus(driverId, RideStatus.COMPLETED);
    long cancelledRides = rideRepository.countByDriverIdAndStatus(driverId, RideStatus.CANCELLED);
    double acceptanceRate = totalTrips > 0 ? (completedRides * 100.0) / totalTrips : 0;
    double cancellationRate = totalTrips > 0 ? (cancelledRides * 100.0) / totalTrips : 0;

    Map<String, Object> distribution = new HashMap<>();
    for (int i = 5; i >= 1; i--) {
      Long count = ratingRepository.countByRateeIdAndRating(driverId, i);
      distribution.put(i + "stars", count != null ? count : 0);
    }

    List<Map<String, Object>> recent = ratingRepository
        .findByRateeIdOrderByCreatedAtDesc(driverId).stream()
        .limit(5)
        .map(r -> {
          Map<String, Object> m = new HashMap<>();
          m.put("rating", r.getRating());
          m.put("review", r.getReviewText() != null ? r.getReviewText() : "");
          m.put("createdAt", r.getCreatedAt());
          return m;
        })
        .collect(Collectors.toList());

    Map<String, Object> result = new HashMap<>();
    result.put("driverId", driverId);
    result.put("averageRating", avg != null ? Math.round(avg * 100.0) / 100.0 : 5.0);
    result.put("totalRatings", total != null ? total : 0);
    result.put("totalTrips", totalTrips);
    result.put("acceptanceRate", Math.round(acceptanceRate * 100.0) / 100.0);
    result.put("cancellationRate", Math.round(cancellationRate * 100.0) / 100.0);
    result.put("distribution", distribution);
    result.put("recentReviews", recent);

    log.info("✅ PERFORMANCE RESPONSE: totalTrips={}, acceptanceRate={}%, cancellationRate={}%",
        totalTrips, Math.round(acceptanceRate * 100.0) / 100.0, Math.round(cancellationRate * 100.0) / 100.0);

    return result;
  }

  public List<Map<String, Object>> getDriverReviews(UUID driverId, int limit) {
    return ratingRepository.findByRateeIdOrderByCreatedAtDesc(driverId).stream()
        .limit(limit)
        .map(r -> {
          Map<String, Object> m = new HashMap<>();
          m.put("rating", r.getRating());
          m.put("review", r.getReviewText() != null ? r.getReviewText() : "");
          m.put("createdAt", r.getCreatedAt());
          m.put("rideId", r.getRideId());
          return m;
        })
        .collect(Collectors.toList());
  }

  @Transactional
  private void updateDriverRating(UUID driverId) {
    DriverProfile driver = driverProfileRepository.findByUserId(driverId).orElse(null);
    if (driver == null)
      return;

    Double avg = ratingRepository.getAverageRatingForDriver(driverId);
    driver.setRating(avg != null ? avg : 5.0);
    driverProfileRepository.save(driver);
  }
}
