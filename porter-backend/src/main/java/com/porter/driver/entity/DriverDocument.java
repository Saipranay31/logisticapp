package com.porter.driver.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "driver_documents")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DriverDocument extends BaseEntity {

  @Column(name = "driver_profile_id", nullable = false)
  private UUID driverProfileId;

  @Column(name = "document_type", nullable = false)
  private String documentType;

  @Column(name = "document_url", nullable = false)
  private String documentUrl;

  @Column(nullable = false)
  private String status = "PENDING";

  @Column(name = "uploaded_at")
  private LocalDateTime uploadedAt;

  @Column(name = "admin_notes", columnDefinition = "TEXT")
  private String adminNotes;

  @Column(name = "approved_by")
  private UUID approvedBy;

  @Column(name = "approved_at")
  private LocalDateTime approvedAt;
}
