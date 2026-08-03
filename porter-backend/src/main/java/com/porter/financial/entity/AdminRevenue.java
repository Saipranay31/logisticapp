package com.porter.financial.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "admin_revenue")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AdminRevenue extends BaseEntity {
  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(name = "commission_amount", nullable = false)
  private double commissionAmount;
}
