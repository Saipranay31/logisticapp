package com.porter.financial.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "user_spending")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserSpending extends BaseEntity {
  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(nullable = false)
  private double amount;
}
