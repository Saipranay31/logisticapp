package com.porter.ride.repository;

import com.porter.common.enums.RideStatus;
import com.porter.ride.entity.Ride;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RideRepository extends JpaRepository<Ride, UUID> {
  List<Ride> findByUserIdOrderByCreatedAtDesc(UUID userId);

  List<Ride> findByDriverIdOrderByCreatedAtDesc(UUID driverId);

  List<Ride> findByStatus(RideStatus status);

  List<Ride> findByStatusIn(List<RideStatus> statuses);

  // ✅ PHASE 1: Find active rides for a driver
  List<Ride> findByDriverIdAndStatusIn(UUID driverId, List<RideStatus> statuses);

  // Find active rides for a user
  List<Ride> findByUserIdAndStatusIn(UUID userId, List<RideStatus> statuses);

  long countByStatus(RideStatus status);

  long countByStatusAndCreatedAtAfter(RideStatus status, LocalDateTime after);

  // ✅ NEW: Count rides by driver and status for performance metrics
  long countByDriverIdAndStatus(UUID driverId, RideStatus status);

  // ✅ NEW: Count ALL rides for a driver (for total trips)
  long countByDriverId(UUID driverId);

  @Query("SELECT COUNT(r) FROM Ride r WHERE r.createdAt >= :after")
  long countByCreatedAtAfter(LocalDateTime after);

  @Query("SELECT COALESCE(SUM(r.actualFare), 0) FROM Ride r WHERE r.status = 'COMPLETED'")
  double sumCompletedFares();

  @Query("SELECT COALESCE(SUM(r.actualFare), 0) FROM Ride r WHERE r.status = 'COMPLETED' AND r.completedAt >= :after")
  double sumCompletedFaresAfter(LocalDateTime after);

  // ─── ANALYTICS QUERIES ───

  long countByStatusAndCreatedAtBetween(RideStatus status, LocalDateTime start, LocalDateTime end);

  @Query("SELECT COALESCE(SUM(r.estimatedFare), 0) FROM Ride r WHERE r.status = :status AND r.createdAt BETWEEN :start AND :end")
  Double sumEstimatedFareByStatusAndCreatedAtBetween(@Param("status") RideStatus status,
      @Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

  @Query("SELECT COUNT(r) FROM Ride r WHERE r.createdAt BETWEEN :start AND :end")
  long countByCreatedAtBetween(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

  // ─── DRIVER ANALYTICS ───

  long countByDriverIdAndStatusAndCreatedAtAfter(UUID driverId, RideStatus status, LocalDateTime after);

  @Query("SELECT COALESCE(SUM(r.actualFare), 0) FROM Ride r WHERE r.driverId = :driverId AND r.status = :status AND r.createdAt >= :after")
  double sumActualFareByDriverAndStatusAfter(@Param("driverId") UUID driverId, @Param("status") RideStatus status, @Param("after") LocalDateTime after);

  @Query("SELECT COALESCE(SUM(r.actualFare), 0) FROM Ride r WHERE r.driverId = :driverId AND r.status = 'COMPLETED'")
  double sumCompletedFaresByDriverId(@Param("driverId") UUID driverId);

  // ─── USER ANALYTICS ───

  long countByUserId(UUID userId);

  long countByUserIdAndCreatedAtAfter(UUID userId, LocalDateTime after);

  @Query("SELECT COALESCE(SUM(r.actualFare), 0) FROM Ride r WHERE r.userId = :userId AND r.status = 'COMPLETED'")
  double sumCompletedFaresByUserId(@Param("userId") UUID userId);

  @Query("SELECT COALESCE(SUM(r.actualFare), 0) FROM Ride r WHERE r.userId = :userId AND r.status = 'COMPLETED' AND r.createdAt > :after")
  double sumCompletedFaresByUserIdAfter(@Param("userId") UUID userId, @Param("after") LocalDateTime after);

  // ─── PESSIMISTIC LOCK FOR CONCURRENCY ───

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("SELECT r FROM Ride r WHERE r.id = :id")
  Optional<Ride> findByIdForUpdate(@Param("id") UUID id);

  // ─── DIRECT STATUS UPDATE (Avoids save() creating duplicates) ───

  @Modifying(flushAutomatically = true, clearAutomatically = true)
  @Query("UPDATE Ride r SET r.status = :status WHERE r.id = :id")
  void updateRideStatus(@Param("id") UUID id, @Param("status") RideStatus status);
}
