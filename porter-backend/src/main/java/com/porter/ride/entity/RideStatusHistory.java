package com.porter.ride.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "ride_status_history")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RideStatusHistory extends BaseEntity {

  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(name = "from_status")
  private String fromStatus;

  @Column(name = "to_status", nullable = false)
  private String toStatus;

  @Column(name = "changed_by")
  private UUID changedBy;

  @Column(name = "changed_at", nullable = false)
  private LocalDateTime changedAt = LocalDateTime.now();
}
