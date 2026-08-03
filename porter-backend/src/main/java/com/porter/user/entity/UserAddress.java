package com.porter.user.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "user_addresses")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserAddress extends BaseEntity {

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(nullable = false)
  private String label;

  @Column(name = "address_line", nullable = false)
  private String addressLine;

  @Column(nullable = false)
  private double latitude;

  @Column(nullable = false)
  private double longitude;
}
