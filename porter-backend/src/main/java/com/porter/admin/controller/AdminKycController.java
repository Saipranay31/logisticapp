package com.porter.admin.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.admin.service.AdminKycService;
import com.porter.driver.dto.ApprovalRequest;
import com.porter.driver.dto.KycDocumentResponse;
import com.porter.config.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/kyc")
@RequiredArgsConstructor
@Slf4j
@PreAuthorize("hasRole('ADMIN')")
public class AdminKycController {

    private final AdminKycService kycService;
    private final JwtTokenProvider jwtTokenProvider;

    @GetMapping("/pending")
    public ResponseEntity<ApiResponse<Page<KycDocumentResponse>>> getPendingKyc(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        log.info("📋 Admin fetching pending KYC documents - page: {}", page);

        Pageable pageable = PageRequest.of(page, size);
        Page<KycDocumentResponse> pendingDocs = kycService.getPendingKycDocuments(pageable);

        return ResponseEntity.ok(ApiResponse.<Page<KycDocumentResponse>>builder()
                .success(true)
                .message("Pending KYC documents retrieved")
                .data(pendingDocs)
                .build());
    }

    @GetMapping("/driver/{driverId}")
    public ResponseEntity<ApiResponse<List<KycDocumentResponse>>> getDriverKyc(
            @PathVariable UUID driverId) {
        log.info("📋 Admin fetching KYC for driver: {}", driverId);

        List<KycDocumentResponse> documents = kycService.getDriverKycDocuments(driverId);

        return ResponseEntity.ok(ApiResponse.<List<KycDocumentResponse>>builder()
                .success(true)
                .message("Driver KYC documents retrieved")
                .data(documents)
                .build());
    }

    @GetMapping("/document/{documentId}")
    public ResponseEntity<ApiResponse<KycDocumentResponse>> getDocumentDetails(
            @PathVariable UUID documentId) {
        try {
            log.info("📋 Admin fetching document details: {}", documentId);
            KycDocumentResponse document = kycService.getDocumentDetails(documentId);

            return ResponseEntity.ok(ApiResponse.<KycDocumentResponse>builder()
                    .success(true)
                    .message("Document details retrieved")
                    .data(document)
                    .build());
        } catch (Exception e) {
            log.error("❌ Failed to fetch document: {}", e.getMessage());
            return ResponseEntity.badRequest().body(ApiResponse.<KycDocumentResponse>builder()
                    .success(false)
                    .message("Document not found: " + e.getMessage())
                    .build());
        }
    }

    @PostMapping("/approve/{documentId}")
    public ResponseEntity<ApiResponse<KycDocumentResponse>> approveDocument(
            @PathVariable UUID documentId,
            @RequestBody(required = false) ApprovalRequest request,
            @RequestHeader("Authorization") String token) {
        try {
            log.info("✅ Admin approving document: {}", documentId);

            // Extract admin ID from token (you might need to adjust based on your token structure)
            String adminNotes = request != null && request.getAdminNotes() != null ? request.getAdminNotes() : "Approved";
            // For now, using a placeholder admin ID - in production, extract from token
            UUID adminId = UUID.fromString("00000000-0000-0000-0000-000000000001");

            KycDocumentResponse response = kycService.approveDocument(documentId, adminNotes, adminId);

            return ResponseEntity.ok(ApiResponse.<KycDocumentResponse>builder()
                    .success(true)
                    .message("Document approved successfully")
                    .data(response)
                    .build());
        } catch (Exception e) {
            log.error("❌ Approval failed: {}", e.getMessage());
            return ResponseEntity.badRequest().body(ApiResponse.<KycDocumentResponse>builder()
                    .success(false)
                    .message("Approval failed: " + e.getMessage())
                    .build());
        }
    }

    @PostMapping("/reject/{documentId}")
    public ResponseEntity<ApiResponse<KycDocumentResponse>> rejectDocument(
            @PathVariable UUID documentId,
            @RequestBody ApprovalRequest request,
            @RequestHeader("Authorization") String token) {
        try {
            log.info("❌ Admin rejecting document: {}", documentId);

            String rejectionReason = request != null && request.getRejectionReason() != null
                    ? request.getRejectionReason()
                    : "Rejected by admin";
            // For now, using a placeholder admin ID - in production, extract from token
            UUID adminId = UUID.fromString("00000000-0000-0000-0000-000000000001");

            KycDocumentResponse response = kycService.rejectDocument(documentId, rejectionReason, adminId);

            return ResponseEntity.ok(ApiResponse.<KycDocumentResponse>builder()
                    .success(true)
                    .message("Document rejected successfully")
                    .data(response)
                    .build());
        } catch (Exception e) {
            log.error("❌ Rejection failed: {}", e.getMessage());
            return ResponseEntity.badRequest().body(ApiResponse.<KycDocumentResponse>builder()
                    .success(false)
                    .message("Rejection failed: " + e.getMessage())
                    .build());
        }
    }

    @GetMapping("/pending/count")
    public ResponseEntity<ApiResponse<Long>> getPendingCount() {
        long count = kycService.getPendingDocumentsCount();
        return ResponseEntity.ok(ApiResponse.<Long>builder()
                .success(true)
                .message("Pending document count retrieved")
                .data(count)
                .build());
    }

    @GetMapping("/all-pending-drivers")
    public ResponseEntity<ApiResponse<List<KycDocumentResponse>>> getAllPendingDrivers() {
        log.info("📋 Admin fetching all drivers with pending KYC");

        List<KycDocumentResponse> drivers = kycService.getDriversWithPendingKyc();

        return ResponseEntity.ok(ApiResponse.<List<KycDocumentResponse>>builder()
                .success(true)
                .message("All pending KYC drivers retrieved")
                .data(drivers)
                .build());
    }
}
