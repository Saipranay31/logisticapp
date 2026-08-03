package com.porter.financial.repository;

import com.porter.financial.entity.DriverEarning;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;
import java.time.LocalDateTime;
import org.springframework.data.repository.query.Param;
@Repository
public interface DriverEarningRepository extends JpaRepository<DriverEarning, UUID> {
  List<DriverEarning> findByDriverId(UUID driverId);

  @Query("SELECT COALESCE(SUM(e.netAmount), 0) FROM DriverEarning e WHERE e.driverId = :driverId")
  double sumNetByDriverId(UUID driverId);

  @Query("SELECT COALESCE(SUM(e.grossAmount), 0) FROM DriverEarning e WHERE e.driverId = :driverId")
  double sumGrossByDriverId(UUID driverId);

  // ✅ NEW: Methods for FinancialService
  @Query("SELECT COUNT(e) FROM DriverEarning e WHERE e.driverId = :driverId")
  long countByDriverId(UUID driverId);

  @Query("SELECT COALESCE(SUM(e.netAmount), 0) FROM DriverEarning e WHERE e.driverId = :driverId AND CAST(e.createdAt AS date) = CAST(CURRENT_TIMESTAMP AS date)")
  double sumNetByDriverIdToday(UUID driverId);

  @Query("SELECT COUNT(e) FROM DriverEarning e WHERE e.driverId = :driverId AND CAST(e.createdAt AS date) = CAST(CURRENT_TIMESTAMP AS date)")
  long countByDriverIdToday(UUID driverId);

  @Query("SELECT COALESCE(SUM(e.netAmount), 0) FROM DriverEarning e WHERE e.driverId = :driverId AND e.createdAt >= :fromDate")
  double sumNetByDriverIdFromDate(UUID driverId, LocalDateTime fromDate);

  @Query("SELECT COUNT(e) FROM DriverEarning e WHERE e.driverId = :driverId AND e.createdAt >= :fromDate")
  long countByDriverIdFromDate(UUID driverId, LocalDateTime fromDate);
  @Query("SELECT CAST(d.createdAt AS date), SUM(d.netAmount) " +
       "FROM DriverEarning d " +
       "WHERE d.driverId = :driverId AND d.createdAt >= :from " +
       "GROUP BY CAST(d.createdAt AS date) " +
       "ORDER BY CAST(d.createdAt AS date)")
List<Object[]> sumNetByDriverIdGroupByDay(
    @Param("driverId") UUID driverId, 
    @Param("from") LocalDateTime from
);
}
