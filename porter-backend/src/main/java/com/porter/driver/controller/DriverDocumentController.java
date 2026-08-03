package com.porter.driver.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.driver.dto.ApprovalRequest;
import com.porter.driver.dto.KycDocumentResponse;
import com.porter.driver.service.DriverDocumentService;
import com.porter.config.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/documents")
@RequiredArgsConstructor
@Slf4j
public class DriverDocumentController {

    private final DriverDocumentService documentService;
    private final JwtTokenProvider jwtTokenProvider;

    @PostMapping("/upload")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<KycDocumentResponse>> uploadDocument(
            @RequestParam("driverProfileId") UUID driverProfileId,
            @RequestParam("documentType") String documentType,
            @RequestParam("file") MultipartFile file,
            @RequestHeader("Authorization") String token) {
        try {
            log.info("📤 Document upload request: type={}, size={}", documentType, file.getSize());

            KycDocumentResponse response = documentService.uploadDocument(driverProfileId, documentType, file);

            return ResponseEntity.ok(ApiResponse.<KycDocumentResponse>builder()
                    .success(true)
                    .message("Document uploaded successfully")
                    .data(response)
                    .build());
        } catch (IOException e) {
            log.error("❌ Upload failed: {}", e.getMessage());
            return ResponseEntity.badRequest().body(ApiResponse.<KycDocumentResponse>builder()
                    .success(false)
                    .message("Upload failed: " + e.getMessage())
                    .build());
        }
    }

    @GetMapping("/driver/{driverId}")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<List<KycDocumentResponse>>> getDriverDocuments(
            @PathVariable UUID driverId) {
        log.info("📋 Fetching documents for driver: {}", driverId);

        List<KycDocumentResponse> documents = documentService.getDriverDocuments(driverId);

        return ResponseEntity.ok(ApiResponse.<List<KycDocumentResponse>>builder()
                .success(true)
                .message("Documents retrieved successfully")
                .data(documents)
                .build());
    }

    @GetMapping("/{documentId}")
    @PreAuthorize("hasAnyRole('DRIVER', 'ADMIN')")
    public ResponseEntity<ApiResponse<KycDocumentResponse>> getDocument(
            @PathVariable UUID documentId) {
        try {
            KycDocumentResponse document = documentService.getDocument(documentId);
            return ResponseEntity.ok(ApiResponse.<KycDocumentResponse>builder()
                    .success(true)
                    .data(document)
                    .build());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.<KycDocumentResponse>builder()
                    .success(false)
                    .message(e.getMessage())
                    .build());
        }
    }

    @DeleteMapping("/{documentId}")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<String>> deleteDocument(
            @PathVariable UUID documentId) {
        try {
            documentService.deleteDocument(documentId);
            return ResponseEntity.ok(ApiResponse.<String>builder()
                    .success(true)
                    .message("Document deleted successfully")
                    .build());
        } catch (IOException e) {
            return ResponseEntity.badRequest().body(ApiResponse.<String>builder()
                    .success(false)
                    .message("Deletion failed: " + e.getMessage())
                    .build());
        }
    }
}
