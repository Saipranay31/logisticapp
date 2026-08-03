package com.porter.admin.service;

import com.porter.driver.dto.KycDocumentResponse;
import com.porter.driver.service.DriverDocumentService;
import com.porter.driver.entity.DriverDocument;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.repository.DriverDocumentRepository;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.common.enums.KycStatus;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class AdminKycService {

    private final DriverDocumentService documentService;
    private final DriverDocumentRepository documentRepository;
    private final DriverProfileRepository profileRepository;

    @Transactional(readOnly = true)
    public Page<KycDocumentResponse> getPendingKycDocuments(Pageable pageable) {
        log.info("📋 Fetching pending KYC documents");
        return documentService.getPendingDocuments(pageable);
    }

    @Transactional(readOnly = true)
    public List<KycDocumentResponse> getDriverKycDocuments(UUID driverId) {
        log.info("📋 Fetching KYC documents for driver: {}", driverId);
        return documentService.getDriverDocuments(driverId);
    }

    @Transactional
    public KycDocumentResponse approveDocument(UUID documentId, String adminNotes, UUID adminId) {
        log.info("✅ Approving document: ID={}, adminId={}", documentId, adminId);

        DriverDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        // Approve document
        KycDocumentResponse response = documentService.approveDocument(documentId, adminNotes, adminId);

        // Check if all documents for this driver are approved
        List<DriverDocument> allDocs = documentRepository.findByDriverProfileId(doc.getDriverProfileId());
        boolean allApproved = allDocs.stream().allMatch(d -> "APPROVED".equals(d.getStatus()));

        // Update driver KYC status if all approved
        if (allApproved) {
            DriverProfile profile = profileRepository.findById(doc.getDriverProfileId())
                    .orElseThrow(() -> new RuntimeException("Driver profile not found"));
            profile.setKycStatus(KycStatus.VERIFIED);
            profileRepository.save(profile);
            log.info("🎉 Driver KYC verified: {}", doc.getDriverProfileId());
        }

        return response;
    }

    @Transactional
    public KycDocumentResponse rejectDocument(UUID documentId, String rejectionReason, UUID adminId) {
        log.info("❌ Rejecting document: ID={}, adminId={}", documentId, adminId);

        DriverDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        // Reject document
        KycDocumentResponse response = documentService.rejectDocument(documentId, rejectionReason, adminId);

        // Update driver KYC status to PENDING (needs resubmission)
        DriverProfile profile = profileRepository.findById(doc.getDriverProfileId())
                .orElseThrow(() -> new RuntimeException("Driver profile not found"));
        profile.setKycStatus(KycStatus.PENDING);
        profileRepository.save(profile);

        return response;
    }

    @Transactional(readOnly = true)
    public long getPendingDocumentsCount() {
        return documentRepository.findByStatus("PENDING").stream().count();
    }

    @Transactional(readOnly = true)
    public List<KycDocumentResponse> getDriversWithPendingKyc() {
        log.info("📋 Fetching all drivers with pending KYC");
        List<DriverDocument> pendingDocs = documentRepository.findByStatus("PENDING");

        return pendingDocs.stream()
                .map(documentService::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public KycDocumentResponse getDocumentDetails(UUID documentId) {
        log.info("📋 Fetching KYC document details: {}", documentId);
        DriverDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));
        return documentService.mapToResponse(doc);
    }
}
