package com.porter.financial.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "driver_earnings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DriverEarning extends BaseEntity {
  @Column(name = "driver_id", nullable = false)
  private UUID driverId;

  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(name = "gross_amount", nullable = false)
  private double grossAmount;

  @Column(nullable = false)
  private double commission;

  @Column(name = "net_amount", nullable = false)
  private double netAmount;
}
