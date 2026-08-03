package com.porter.analytics.service;

import com.porter.common.enums.KycStatus;
import com.porter.common.enums.PaymentStatus;
import com.porter.common.enums.RideStatus;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.payment.repository.PaymentRepository;
import com.porter.ride.repository.RideRepository;
import com.porter.auth.repository.UserRepository;
import com.porter.support.repository.SupportTicketRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

/**
 * Analytics service providing aggregated data for admin dashboards.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AnalyticsService {

  private final RideRepository rideRepository;
  private final PaymentRepository paymentRepository;
  private final UserRepository userRepository;
  private final DriverProfileRepository driverProfileRepository;
  private final SupportTicketRepository supportTicketRepository;

  /**
   * Revenue analytics with date range.
   */
  public Map<String, Object> getRevenueAnalytics(LocalDate startDate, LocalDate endDate) {
    LocalDateTime start = (startDate != null ? startDate : LocalDate.now().minusDays(30)).atStartOfDay();
    LocalDateTime end = (endDate != null ? endDate : LocalDate.now()).atTime(23, 59, 59);

    long totalRides = rideRepository.countByStatusAndCreatedAtBetween(RideStatus.COMPLETED, start, end);
    Double totalRevenue = rideRepository.sumEstimatedFareByStatusAndCreatedAtBetween(RideStatus.COMPLETED, start, end);
    if (totalRevenue == null)
      totalRevenue = 0.0;
    double avgFare = totalRides > 0 ? totalRevenue / totalRides : 0;

    long cancelledRides = rideRepository.countByStatusAndCreatedAtBetween(RideStatus.CANCELLED, start, end);
    long allRides = rideRepository.countByCreatedAtBetween(start, end);

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("totalRevenue", Math.round(totalRevenue * 100.0) / 100.0);
    result.put("totalRides", totalRides);
    result.put("averageFare", Math.round(avgFare * 100.0) / 100.0);
    result.put("cancelledRides", cancelledRides);
    result.put("totalRidesRequested", allRides);
    result.put("completionRate", allRides > 0 ? Math.round((double) totalRides / allRides * 10000.0) / 100.0 : 0);
    result.put("platformCommission", Math.round(totalRevenue * 0.20 * 100.0) / 100.0);
    result.put("driverPayout", Math.round(totalRevenue * 0.80 * 100.0) / 100.0);
    result.put("startDate", start.toLocalDate().toString());
    result.put("endDate", end.toLocalDate().toString());

    return result;
  }

  /**
   * Driver analytics.
   */
  public Map<String, Object> getDriverAnalytics() {
    long totalDrivers = driverProfileRepository.count();
    long onlineDrivers = driverProfileRepository.countByIsOnline(true);
    long verifiedDrivers = driverProfileRepository.countByKycStatus(KycStatus.VERIFIED);

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("totalDrivers", totalDrivers);
    result.put("onlineNow", onlineDrivers);
    result.put("verifiedDrivers", verifiedDrivers);
    result.put("pendingKyc", totalDrivers - verifiedDrivers);
    result.put("onlinePercentage", totalDrivers > 0
        ? Math.round((double) onlineDrivers / totalDrivers * 10000.0) / 100.0
        : 0);

    return result;
  }

  /**
   * User analytics.
   */
  public Map<String, Object> getUserAnalytics() {
    long totalUsers = userRepository.count();
    LocalDateTime weekAgo = LocalDateTime.now().minusDays(7);
    long newThisWeek = userRepository.countByCreatedAtAfter(weekAgo);

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("totalUsers", totalUsers);
    result.put("newThisWeek", newThisWeek);

    return result;
  }

  /**
   * Payment analytics.
   */
  public Map<String, Object> getPaymentAnalytics() {
    long totalPayments = paymentRepository.count();
    long successPayments = paymentRepository.countByPaymentStatus(PaymentStatus.COMPLETED);
    long failedPayments = paymentRepository.countByPaymentStatus(PaymentStatus.FAILED);
    long pendingPayments = paymentRepository.countByPaymentStatus(PaymentStatus.PENDING);

    Double totalProcessed = paymentRepository.sumAmountByPaymentStatus(PaymentStatus.COMPLETED);
    if (totalProcessed == null)
      totalProcessed = 0.0;

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("totalPayments", totalPayments);
    result.put("successfulPayments", successPayments);
    result.put("failedPayments", failedPayments);
    result.put("pendingPayments", pendingPayments);
    result.put("totalProcessedAmount", Math.round(totalProcessed * 100.0) / 100.0);
    result.put("successRate", totalPayments > 0
        ? Math.round((double) successPayments / totalPayments * 10000.0) / 100.0
        : 0);
    result.put("failureRate", totalPayments > 0
        ? Math.round((double) failedPayments / totalPayments * 10000.0) / 100.0
        : 0);

    return result;
  }

  /**
   * Support ticket analytics.
   */
  public Map<String, Object> getSupportAnalytics() {
    long totalTickets = supportTicketRepository.count();
    long openTickets = supportTicketRepository.countByStatus("OPEN");
    long inProgressTickets = supportTicketRepository.countByStatus("IN_PROGRESS");
    long resolvedTickets = supportTicketRepository.countByStatus("RESOLVED");

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("totalTickets", totalTickets);
    result.put("openTickets", openTickets);
    result.put("inProgressTickets", inProgressTickets);
    result.put("resolvedTickets", resolvedTickets);
    result.put("resolutionRate", totalTickets > 0
        ? Math.round((double) resolvedTickets / totalTickets * 10000.0) / 100.0
        : 0);

    return result;
  }
}
