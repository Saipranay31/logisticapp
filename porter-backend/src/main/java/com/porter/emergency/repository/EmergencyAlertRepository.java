package com.porter.emergency.repository;

import com.porter.emergency.entity.EmergencyAlert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface EmergencyAlertRepository extends JpaRepository<EmergencyAlert, UUID> {
  List<EmergencyAlert> findByUserId(UUID userId);

  List<EmergencyAlert> findByStatusOrderByCreatedAtDesc(String status);

  List<EmergencyAlert> findByRideId(UUID rideId);
}
