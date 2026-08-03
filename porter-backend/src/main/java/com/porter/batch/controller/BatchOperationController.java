package com.porter.batch.controller;

import com.porter.batch.service.BatchOperationService;
import com.porter.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Admin batch operation endpoints.
 */
@RestController
@RequestMapping("/api/admin/batch")
@RequiredArgsConstructor
public class BatchOperationController {

  private final BatchOperationService batchOperationService;

  @PostMapping("/approve-kyc")
  public ResponseEntity<ApiResponse<Map<String, Object>>> batchApproveKyc(
      @RequestBody Map<String, Object> body) {
    @SuppressWarnings("unchecked")
    List<String> driverIdStrings = (List<String>) body.get("driverIds");
    List<UUID> driverIds = driverIdStrings.stream().map(UUID::fromString).toList();
    return ResponseEntity.ok(ApiResponse.success(
        batchOperationService.batchApproveKyc(driverIds)));
  }

  @PostMapping("/send-notification")
  public ResponseEntity<ApiResponse<Map<String, Object>>> batchSendNotification(
      @RequestBody Map<String, String> body) {
    return ResponseEntity.ok(ApiResponse.success(
        batchOperationService.batchSendNotification(
            body.get("targetAudience"),
            body.get("title"),
            body.get("message"))));
  }

  @PostMapping("/export-data")
  public ResponseEntity<ApiResponse<Map<String, Object>>> exportData(
      @RequestBody Map<String, String> body) {
    return ResponseEntity.ok(ApiResponse.success(
        batchOperationService.exportData(
            body.get("dataType"),
            body.get("startDate"),
            body.get("endDate"))));
  }
}
