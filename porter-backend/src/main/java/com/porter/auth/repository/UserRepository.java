package com.porter.auth.repository;

import com.porter.auth.entity.User;
import com.porter.common.enums.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
  Optional<User> findByPhone(String phone);

  Optional<User> findByEmail(String email);

  Optional<User> findByEmailAndRole(String email, Role role);

  boolean existsByPhone(String phone);

  boolean existsByEmail(String email);

  List<User> findByRole(Role role);

  long countByRole(Role role);

  long countByRoleAndIsActive(Role role, boolean isActive);

  // Analytics
  long countByCreatedAtAfter(java.time.LocalDateTime after);
}
