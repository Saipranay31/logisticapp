package com.porter.analytics.controller;

import com.porter.analytics.service.AnalyticsService;
import com.porter.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;

/**
 * Admin analytics endpoints.
 */
@RestController
@RequestMapping("/api/admin/analytics")
@RequiredArgsConstructor
public class AnalyticsController {

  private final AnalyticsService analyticsService;

  @GetMapping("/revenue")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getRevenueAnalytics(
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
    return ResponseEntity.ok(ApiResponse.success(
        analyticsService.getRevenueAnalytics(startDate, endDate)));
  }

  @GetMapping("/drivers")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getDriverAnalytics() {
    return ResponseEntity.ok(ApiResponse.success(analyticsService.getDriverAnalytics()));
  }

  @GetMapping("/users")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getUserAnalytics() {
    return ResponseEntity.ok(ApiResponse.success(analyticsService.getUserAnalytics()));
  }

  @GetMapping("/payments")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getPaymentAnalytics() {
    return ResponseEntity.ok(ApiResponse.success(analyticsService.getPaymentAnalytics()));
  }

  @GetMapping("/support")
  public ResponseEntity<ApiResponse<Map<String, Object>>> getSupportAnalytics() {
    return ResponseEntity.ok(ApiResponse.success(analyticsService.getSupportAnalytics()));
  }
}
