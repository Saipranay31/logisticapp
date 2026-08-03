package com.porter.driver.entity;

import com.porter.common.entity.BaseEntity;
import com.porter.common.enums.KycStatus;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "driver_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DriverProfile extends BaseEntity {

  @Column(name = "user_id", nullable = false, unique = true)
  private UUID userId;

  @Column(name = "avatar_url")
  private String avatarUrl;

  @Column(name = "license_number")
  private String licenseNumber;

  // ✅ NEW: Store driver's full name in profile (synced with User.fullName)
  @Column(name = "full_name")
  private String fullName;

  @Enumerated(EnumType.STRING)
  @Column(name = "kyc_status", nullable = false)
  private KycStatus kycStatus = KycStatus.PENDING;

  @Column(name = "is_online", nullable = false)
  private boolean isOnline = false;

  @Column(nullable = false)
  private double rating = 5.0;

  @Column(name = "total_rides", nullable = false)
  private int totalRides = 0;
}
