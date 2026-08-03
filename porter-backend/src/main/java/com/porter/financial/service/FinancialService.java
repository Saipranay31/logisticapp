package com.porter.financial.service;

import com.porter.financial.entity.AdminRevenue;
import com.porter.financial.entity.DriverEarning;
import com.porter.financial.entity.UserSpending;
import com.porter.financial.repository.AdminRevenueRepository;
import com.porter.financial.repository.DriverEarningRepository;
import com.porter.financial.repository.UserSpendingRepository;
import com.porter.ride.entity.Ride;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Map;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.UUID;

/**
 * Financial service handling commission splits and earnings tracking.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FinancialService {

  private final UserSpendingRepository userSpendingRepository;
  private final DriverEarningRepository driverEarningRepository;
  private final AdminRevenueRepository adminRevenueRepository;

  @Value("${porter.commission.platform-percentage:20.0}")
  private double platformCommissionPercent;

  /**
   * Record financial transaction for a completed ride.
   * Splits fare: driver gets (100% - commission), platform gets commission.
   */
  @Transactional
  public void recordTransaction(Ride ride) {
    double fare = ride.getActualFare();
    double commission = fare * (platformCommissionPercent / 100.0);
    double driverEarning = fare - commission;

    // User spending
    userSpendingRepository.save(UserSpending.builder()
        .userId(ride.getUserId())
        .rideId(ride.getId())
        .amount(fare)
        .build());

    // Driver earnings
    if (ride.getDriverId() != null) {
      driverEarningRepository.save(DriverEarning.builder()
          .driverId(ride.getDriverId())
          .rideId(ride.getId())
          .grossAmount(fare)
          .commission(commission)
          .netAmount(driverEarning)
          .build());
    }

    // Admin revenue
    adminRevenueRepository.save(AdminRevenue.builder()
        .rideId(ride.getId())
        .commissionAmount(commission)
        .build());

    log.info("Financial transaction recorded - Fare: ₹{}, Commission: ₹{}, Driver: ₹{}",
        fare, commission, driverEarning);
  }

  public double getUserTotalSpending(UUID userId) {
    return userSpendingRepository.sumByUserId(userId);
  }

  public double getDriverTotalEarnings(UUID driverId) {
    return driverEarningRepository.sumNetByDriverId(driverId);
  }

  public long getDriverTotalRides(UUID driverId) {
    return driverEarningRepository.countByDriverId(driverId);
  }

  public double getDriverEarningsToday(UUID driverId) {
    return driverEarningRepository.sumNetByDriverIdToday(driverId);
  }

  public long getDriverRidesToday(UUID driverId) {
    return driverEarningRepository.countByDriverIdToday(driverId);
  }

  public double getDriverEarningsWeekly(UUID driverId) {
    LocalDateTime weekStart = LocalDateTime.now().minusDays(7);
    return driverEarningRepository.sumNetByDriverIdFromDate(driverId, weekStart);
  }

  public long getDriverRidesWeekly(UUID driverId) {
    LocalDateTime weekStart = LocalDateTime.now().minusDays(7);
    return driverEarningRepository.countByDriverIdFromDate(driverId, weekStart);
  }

  public double getTotalPlatformRevenue() {
    return adminRevenueRepository.sumTotalRevenue();
  }
  public Map<String, Object> getDriverDailyBreakdown(UUID driverId) {
  LocalDateTime weekStart = LocalDateTime.now().minusDays(7);
  List<Object[]> results = driverEarningRepository.sumNetByDriverIdGroupByDay(driverId, weekStart);
  
  Map<String, Object> breakdown = new LinkedHashMap<>();
  for (Object[] row : results) {
    String date = row[0].toString(); // "2025-03-26"
    double amount = ((Number) row[1]).doubleValue();
    breakdown.put(date, amount);
  }
  return breakdown;
}
}
