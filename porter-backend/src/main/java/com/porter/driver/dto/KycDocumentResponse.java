package com.porter.driver.dto;

import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class KycDocumentResponse {
    private UUID id;
    private UUID driverProfileId;
    private String driverName;
    private String driverPhone;
    private String documentType;
    private String documentUrl;
    private String status;
    private LocalDateTime uploadedAt;
    private String adminNotes;
    private UUID approvedBy;
    private LocalDateTime approvedAt;
    private Integer totalDocuments;
    private Integer approvedDocuments;
    private Integer rejectedDocuments;
}
