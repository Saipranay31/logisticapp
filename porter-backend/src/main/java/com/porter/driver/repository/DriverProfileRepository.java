package com.porter.driver.repository;

import com.porter.driver.entity.DriverProfile;
import com.porter.common.enums.KycStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DriverProfileRepository extends JpaRepository<DriverProfile, UUID> {
  Optional<DriverProfile> findByUserId(UUID userId);

  List<DriverProfile> findByIsOnline(boolean isOnline);

  List<DriverProfile> findByKycStatus(KycStatus status);

  long countByIsOnline(boolean isOnline);

  long countByKycStatus(KycStatus status);
}
