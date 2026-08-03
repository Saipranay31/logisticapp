package com.porter.ride.repository;

import com.porter.ride.entity.RideLocationUpdate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RideLocationUpdateRepository extends JpaRepository<RideLocationUpdate, UUID> {

  List<RideLocationUpdate> findByRideIdOrderByRecordedAtAsc(UUID rideId);

  Optional<RideLocationUpdate> findFirstByRideIdOrderByRecordedAtDesc(UUID rideId);

  Long countByRideId(UUID rideId);
}
