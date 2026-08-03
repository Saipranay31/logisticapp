package com.porter.financial.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.financial.service.FinancialService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/financial")
@RequiredArgsConstructor
public class FinancialController {

  private final FinancialService financialService;

  @GetMapping("/user/spending")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getUserSpending(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    double total = financialService.getUserTotalSpending(userId);
    return ResponseEntity.ok(ApiResponse.success(Map.of("totalSpending", total)));
  }

  @GetMapping("/driver/earnings")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getDriverEarnings(
      Authentication auth,
      @RequestParam(defaultValue = "daily") String period) {
    UUID driverId = UUID.fromString(auth.getName());

    double totalEarnings;
    long totalRides;

    switch (period.toLowerCase()) {
      case "daily":
        totalEarnings = financialService.getDriverEarningsToday(driverId);
        totalRides = financialService.getDriverRidesToday(driverId);
        break;
      case "weekly":
  totalEarnings = financialService.getDriverEarningsWeekly(driverId);
  totalRides = financialService.getDriverRidesWeekly(driverId);
  Map<String, Object> dailyBreakdown = financialService.getDriverDailyBreakdown(driverId); // add this
  
  return ResponseEntity.ok(ApiResponse.success(Map.of(
      "totalEarnings", totalEarnings,
      "totalRides", totalRides,
      "averagePerRide", totalRides > 0 ? totalEarnings / totalRides : 0,
      "dailyBreakdown", dailyBreakdown
  )));
      case "total":
      default:
        totalEarnings = financialService.getDriverTotalEarnings(driverId);
        totalRides = financialService.getDriverTotalRides(driverId);
        break;
      
    }

    Map<String, Object> data = Map.of(
        "totalEarnings", totalEarnings,
        "totalRides", totalRides
    );

    return ResponseEntity.ok(ApiResponse.success(data));
  }

  @GetMapping("/admin/revenue")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getPlatformRevenue() {
    double total = financialService.getTotalPlatformRevenue();
    return ResponseEntity.ok(ApiResponse.success(Map.of("totalRevenue", total)));
  }
}
