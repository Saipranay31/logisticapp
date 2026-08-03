package com.porter.ride.repository;

import com.porter.ride.entity.RideRating;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RideRatingRepository extends JpaRepository<RideRating, UUID> {

  Optional<RideRating> findByRideId(UUID rideId);

  Optional<RideRating> findByRideIdAndRaterId(UUID rideId, UUID raterId);

  List<RideRating> findByRateeIdOrderByCreatedAtDesc(UUID rateeId);

  List<RideRating> findByRaterId(UUID raterId);

  @Query("SELECT AVG(r.rating) FROM RideRating r WHERE r.rateeId = ?1")
  Double getAverageRatingForDriver(UUID driverId);

  @Query("SELECT COUNT(r) FROM RideRating r WHERE r.rateeId = ?1")
  Long getTotalRatingsForDriver(UUID driverId);

  @Query("SELECT COUNT(r) FROM RideRating r WHERE r.rateeId = ?1 AND r.rating = ?2")
  Long countByRateeIdAndRating(UUID driverId, Integer rating);
}
