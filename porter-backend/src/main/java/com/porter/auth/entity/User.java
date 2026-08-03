package com.porter.auth.entity;

import com.porter.common.entity.BaseEntity;
import com.porter.common.enums.Role;
import jakarta.persistence.*;
import lombok.*;

/**
 * Core user identity entity shared across all roles.
 */
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User extends BaseEntity {

  @Column(unique = true)
  private String phone;

  @Column(unique = true)
  private String email;

  @Column(name = "password_hash")
  private String passwordHash;

  @Column(name = "full_name", nullable = false)
  private String fullName;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private Role role;

  @Column(name = "is_active", nullable = false)
  private boolean isActive = true;
}
