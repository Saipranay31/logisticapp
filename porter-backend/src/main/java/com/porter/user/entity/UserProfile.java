package com.porter.user.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "user_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfile extends BaseEntity {

  @Column(name = "user_id", nullable = false, unique = true)
  private UUID userId;

  @Column(name = "avatar_url")
  private String avatarUrl;

  @Column(name = "default_address_id")
  private UUID defaultAddressId;
}
