package com.porter.emergency.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "emergency_contacts", indexes = {
    @Index(name = "idx_ec_user", columnList = "user_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmergencyContact extends BaseEntity {

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(name = "contact_name", nullable = false)
  private String contactName;

  @Column(name = "contact_phone", nullable = false)
  private String contactPhone;

  private String relation;

  @Column(name = "is_default", nullable = false)
  private Boolean isDefault = false;
}
