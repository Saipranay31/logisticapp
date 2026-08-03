package com.porter.driver.repository;

import com.porter.driver.entity.DriverVehicle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DriverVehicleRepository extends JpaRepository<DriverVehicle, UUID> {
  List<DriverVehicle> findByDriverProfileId(UUID driverProfileId);

  Optional<DriverVehicle> findByDriverProfileIdAndIsActive(UUID driverProfileId, boolean isActive);
}
