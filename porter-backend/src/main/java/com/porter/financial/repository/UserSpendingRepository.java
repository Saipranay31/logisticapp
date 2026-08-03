package com.porter.financial.repository;

import com.porter.financial.entity.UserSpending;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface UserSpendingRepository extends JpaRepository<UserSpending, UUID> {
  List<UserSpending> findByUserId(UUID userId);

  @Query("SELECT COALESCE(SUM(s.amount), 0) FROM UserSpending s WHERE s.userId = :userId")
  double sumByUserId(UUID userId);
}
