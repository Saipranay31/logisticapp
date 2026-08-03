package com.porter.auth.repository;

import com.porter.auth.entity.AccountLockout;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface AccountLockoutRepository extends JpaRepository<AccountLockout, UUID> {
  Optional<AccountLockout> findByPhone(String phone);

  void deleteByPhone(String phone);
}
