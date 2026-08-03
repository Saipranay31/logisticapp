package com.porter.driver.service;

import com.porter.driver.dto.KycDocumentResponse;
import com.porter.driver.entity.DriverDocument;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.repository.DriverDocumentRepository;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.auth.entity.User;
import com.porter.auth.repository.UserRepository;
import com.porter.file.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class DriverDocumentService {

    private final DriverDocumentRepository documentRepository;
    private final DriverProfileRepository profileRepository;
    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;

    @Transactional
    public KycDocumentResponse uploadDocument(UUID driverProfileId, String documentType, MultipartFile file) throws IOException {
        log.info("📄 Uploading document for driver: {}, type: {}", driverProfileId, documentType);

        // Save file
        String fileUrl = fileStorageService.saveFile(file, "kyc-documents");

        // Create document record
        DriverDocument document = DriverDocument.builder()
                .driverProfileId(driverProfileId)
                .documentType(documentType)
                .documentUrl(fileUrl)
                .status("PENDING")
                .uploadedAt(LocalDateTime.now())
                .build();

        DriverDocument saved = documentRepository.save(document);
        log.info("✅ Document uploaded: ID={}, URL={}", saved.getId(), fileUrl);

        return mapToResponse(saved);
    }

    @Transactional(readOnly = true)
    public Page<KycDocumentResponse> getPendingDocuments(Pageable pageable) {
        return documentRepository.findByStatus("PENDING", pageable)
                .map(this::mapToResponse);
    }

    @Transactional(readOnly = true)
    public List<KycDocumentResponse> getDriverDocuments(UUID driverProfileId) {
        return documentRepository.findByDriverProfileId(driverProfileId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public KycDocumentResponse getDocument(UUID documentId) {
        DriverDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));
        return mapToResponse(doc);
    }

    @Transactional
    public KycDocumentResponse approveDocument(UUID documentId, String adminNotes, UUID adminId) {
        DriverDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        doc.setStatus("APPROVED");
        doc.setAdminNotes(adminNotes != null ? adminNotes : "Approved");
        doc.setApprovedBy(adminId);
        doc.setApprovedAt(LocalDateTime.now());

        DriverDocument saved = documentRepository.save(doc);
        log.info("✅ Document approved: ID={}, approvedBy={}", documentId, adminId);

        return mapToResponse(saved);
    }

    @Transactional
    public KycDocumentResponse rejectDocument(UUID documentId, String rejectionReason, UUID adminId) {
        DriverDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        doc.setStatus("REJECTED");
        doc.setAdminNotes(rejectionReason != null ? rejectionReason : "Rejected");
        doc.setApprovedBy(adminId);
        doc.setApprovedAt(LocalDateTime.now());

        DriverDocument saved = documentRepository.save(doc);
        log.info("❌ Document rejected: ID={}, rejectionReason={}", documentId, rejectionReason);

        return mapToResponse(saved);
    }

    @Transactional
    public void deleteDocument(UUID documentId) throws IOException {
        DriverDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        // Delete file
        fileStorageService.deleteFile(doc.getDocumentUrl());

        // Delete record
        documentRepository.deleteById(documentId);
        log.info("✅ Document deleted: ID={}", documentId);
    }

    public KycDocumentResponse mapToResponse(DriverDocument doc) {
        // Get driver info
        DriverProfile profile = profileRepository.findById(doc.getDriverProfileId()).orElse(null);
        String driverName = "Unknown";
        String driverPhone = "N/A";

        if (profile != null) {
            User user = userRepository.findById(profile.getUserId()).orElse(null);
            if (user != null) {
                driverName = user.getFullName();
                driverPhone = user.getPhone();
            }
        }

        // Count documents
        List<DriverDocument> allDocs = documentRepository.findByDriverProfileId(doc.getDriverProfileId());
        long approvedCount = allDocs.stream().filter(d -> "APPROVED".equals(d.getStatus())).count();
        long rejectedCount = allDocs.stream().filter(d -> "REJECTED".equals(d.getStatus())).count();

        return KycDocumentResponse.builder()
                .id(doc.getId())
                .driverProfileId(doc.getDriverProfileId())
                .driverName(driverName)
                .driverPhone(driverPhone)
                .documentType(doc.getDocumentType())
                .documentUrl(doc.getDocumentUrl())
                .status(doc.getStatus())
                .uploadedAt(doc.getUploadedAt())
                .adminNotes(doc.getAdminNotes())
                .approvedBy(doc.getApprovedBy())
                .approvedAt(doc.getApprovedAt())
                .totalDocuments(allDocs.size())
                .approvedDocuments((int) approvedCount)
                .rejectedDocuments((int) rejectedCount)
                .build();
    }
}
