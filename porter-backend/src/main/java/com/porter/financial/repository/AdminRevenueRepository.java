package com.porter.financial.repository;

import com.porter.financial.entity.AdminRevenue;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.UUID;

@Repository
public interface AdminRevenueRepository extends JpaRepository<AdminRevenue, UUID> {
  @Query("SELECT COALESCE(SUM(a.commissionAmount), 0) FROM AdminRevenue a")
  double sumTotalRevenue();
}
