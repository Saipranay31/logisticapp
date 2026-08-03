package com.porter.ride.repository;

import com.porter.ride.entity.RideStatusHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface RideStatusHistoryRepository extends JpaRepository<RideStatusHistory, UUID> {
  List<RideStatusHistory> findByRideIdOrderByChangedAtAsc(UUID rideId);
}
