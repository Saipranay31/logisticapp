package com.porter.ride.repository;

import com.porter.ride.entity.RideDispute;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RideDisputeRepository extends JpaRepository<RideDispute, UUID> {
  Optional<RideDispute> findByRideId(UUID rideId);

  List<RideDispute> findByUserId(UUID userId);

  List<RideDispute> findByStatusOrderByCreatedAtDesc(String status);

  List<RideDispute> findAllByOrderByCreatedAtDesc();
}
