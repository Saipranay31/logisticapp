package com.porter.admin.service;

import com.porter.admin.dto.DashboardDto;
import com.porter.admin.dto.DriverAnalyticsDto;
import com.porter.admin.dto.UserDetailDto;
import com.porter.auth.entity.User;
import com.porter.auth.repository.UserRepository;
import com.porter.common.enums.KycStatus;
import com.porter.common.enums.Role;
import com.porter.common.enums.RideStatus;
import com.porter.user.dto.UserProfileDto;
import com.porter.driver.dto.DriverProfileDto;
import com.porter.driver.entity.DriverDocument;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.driver.service.DriverService;
import com.porter.financial.repository.AdminRevenueRepository;
import com.porter.ride.dto.RideDto;
import com.porter.ride.repository.RideRatingRepository;
import com.porter.ride.repository.RideRepository;
import com.porter.ride.service.RideService;
import com.porter.user.repository.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminService {

  private final UserRepository userRepository;
  private final DriverProfileRepository driverProfileRepository;
  private final RideRepository rideRepository;
  private final RideRatingRepository rideRatingRepository;
  private final AdminRevenueRepository adminRevenueRepository;
  private final DriverService driverService;
  private final RideService rideService;
  private final UserProfileRepository userProfileRepository;

  public DashboardDto getDashboard() {
    LocalDateTime todayStart = LocalDateTime.now().withHour(0).withMinute(0).withSecond(0).withNano(0);
    return DashboardDto.builder()
        .totalUsers(userRepository.countByRole(Role.USER))
        .totalDrivers(userRepository.countByRole(Role.DRIVER))
        .activeDrivers(driverProfileRepository.countByIsOnline(true))
        .totalRides(rideRepository.count())
        .activeRides(rideRepository.countByStatus(RideStatus.IN_PROGRESS) +
            rideRepository.countByStatus(RideStatus.ASSIGNED) +
            rideRepository.countByStatus(RideStatus.ARRIVED))
        .completedRides(rideRepository.countByStatus(RideStatus.COMPLETED))
        .totalRevenue(rideRepository.sumCompletedFares())
        .todayRevenue(rideRepository.sumCompletedFaresAfter(todayStart))
        .todayRides(rideRepository.countByCreatedAtAfter(todayStart))
        .build();
  }

  public List<DriverProfileDto> getAllDrivers() {
    return driverService.getAllDrivers();
  }

  @Transactional
  public void setDriverActive(UUID userId, boolean active) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new RuntimeException("User not found"));
    user.setActive(active);
    userRepository.save(user);
    if (active) {
      driverService.updateKycStatus(
          driverProfileRepository.findByUserId(userId)
              .orElseThrow(() -> new RuntimeException("Driver profile not found")).getId(),
          KycStatus.VERIFIED);
    }
  }

  public DriverAnalyticsDto getDriverAnalytics(UUID userId) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new RuntimeException("User not found"));
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new RuntimeException("Driver profile not found"));

    LocalDateTime now = LocalDateTime.now();
    LocalDateTime todayStart = now.withHour(0).withMinute(0).withSecond(0).withNano(0);
    LocalDateTime weekStart = now.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        .withHour(0).withMinute(0).withSecond(0).withNano(0);
    LocalDateTime monthStart = now.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0).withNano(0);

    Long totalRatings = rideRatingRepository.getTotalRatingsForDriver(userId);
    Map<String, Long> ratingDist = new HashMap<>();
    for (int i = 5; i >= 1; i--) {
      Long cnt = rideRatingRepository.countByRateeIdAndRating(userId, i);
      ratingDist.put(i + "stars", cnt != null ? cnt : 0L);
    }

    return DriverAnalyticsDto.builder()
        .userId(userId)
        .fullName(user.getFullName())
        .phone(user.getPhone())
        .avatarUrl(profile.getAvatarUrl())
        .rating(profile.getRating())
        .totalRides(profile.getTotalRides())
        .kycStatus(profile.getKycStatus().name())
        .isOnline(profile.isOnline())
        .isActive(user.isActive())
        .licenseNumber(profile.getLicenseNumber())
        .todayRides(rideRepository.countByDriverIdAndStatusAndCreatedAtAfter(userId, RideStatus.COMPLETED, todayStart))
        .todayEarnings(rideRepository.sumActualFareByDriverAndStatusAfter(userId, RideStatus.COMPLETED, todayStart))
        .weekRides(rideRepository.countByDriverIdAndStatusAndCreatedAtAfter(userId, RideStatus.COMPLETED, weekStart))
        .weekEarnings(rideRepository.sumActualFareByDriverAndStatusAfter(userId, RideStatus.COMPLETED, weekStart))
        .monthRides(rideRepository.countByDriverIdAndStatusAndCreatedAtAfter(userId, RideStatus.COMPLETED, monthStart))
        .monthEarnings(rideRepository.sumActualFareByDriverAndStatusAfter(userId, RideStatus.COMPLETED, monthStart))
        .totalEarnings(rideRepository.sumCompletedFaresByDriverId(userId))
        .totalRatings(totalRatings != null ? totalRatings : 0L)
        .ratingDistribution(ratingDist)
        .build();
  }

  public List<RideDto> getActiveRides() {
    return rideService.getActiveRides();
  }

  public List<RideDto> getAdminRides(String status) {
    return rideService.getAllRidesByStatus(status);
  }

  public List<UserProfileDto> getAllUsers() {
    return userRepository.findByRole(Role.USER).stream()
        .map(user -> UserProfileDto.builder()
            .userId(user.getId())
            .fullName(user.getFullName())
            .phone(user.getPhone())
            .isActive(user.isActive())
            .build())
        .collect(Collectors.toList());
  }

  public UserDetailDto getUserDetail(UUID userId) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new RuntimeException("User not found"));

    String avatarUrl = userProfileRepository.findByUserId(userId)
        .map(p -> p.getAvatarUrl())
        .orElse(null);

    LocalDateTime now = LocalDateTime.now();
    LocalDateTime todayStart = now.withHour(0).withMinute(0).withSecond(0).withNano(0);
    LocalDateTime weekStart = now.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        .withHour(0).withMinute(0).withSecond(0).withNano(0);
    LocalDateTime monthStart = now.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0).withNano(0);

    // User ratings (rated by drivers)
    Double avgRating = rideRatingRepository.getAverageRatingForDriver(userId);
    Long totalRatings = rideRatingRepository.getTotalRatingsForDriver(userId);
    Map<String, Long> dist = new HashMap<>();
    for (int i = 5; i >= 1; i--) {
      Long cnt = rideRatingRepository.countByRateeIdAndRating(userId, i);
      dist.put(i + "stars", cnt != null ? cnt : 0L);
    }

    return UserDetailDto.builder()
        .userId(userId)
        .fullName(user.getFullName())
        .phone(user.getPhone())
        .email(user.getEmail())
        .avatarUrl(avatarUrl)
        .isActive(user.isActive())
        .joinedAt(user.getCreatedAt())
        .totalRides(rideRepository.countByUserId(userId))
        .todayRides(rideRepository.countByUserIdAndCreatedAtAfter(userId, todayStart))
        .weekRides(rideRepository.countByUserIdAndCreatedAtAfter(userId, weekStart))
        .monthRides(rideRepository.countByUserIdAndCreatedAtAfter(userId, monthStart))
        .totalSpent(rideRepository.sumCompletedFaresByUserId(userId))
        .todaySpent(rideRepository.sumCompletedFaresByUserIdAfter(userId, todayStart))
        .weekSpent(rideRepository.sumCompletedFaresByUserIdAfter(userId, weekStart))
        .monthSpent(rideRepository.sumCompletedFaresByUserIdAfter(userId, monthStart))
        .averageRating(avgRating != null ? Math.round(avgRating * 100.0) / 100.0 : 0.0)
        .totalRatings(totalRatings != null ? totalRatings : 0L)
        .ratingDistribution(dist)
        .build();
  }

  @Transactional
  public void setUserActive(UUID userId, boolean active) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new RuntimeException("User not found"));
    user.setActive(active);
    userRepository.save(user);
  }

  public RideDto getRideDetail(UUID rideId) {
    return rideService.getRide(rideId);
  }

  public DriverProfileDto approveDriverKyc(UUID userId, boolean approve) {
    return driverService.approveKyc(userId, approve);
  }

  public List<DriverDocument> getDriverDocuments(UUID userId) {
    return driverService.getDocuments(userId);
  }
}
