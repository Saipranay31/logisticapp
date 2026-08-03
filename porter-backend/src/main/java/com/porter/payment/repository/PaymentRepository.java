package com.porter.payment.repository;

import com.porter.common.enums.PaymentStatus;
import com.porter.payment.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, UUID> {
  Optional<Payment> findByRideId(UUID rideId);

  List<Payment> findByUserId(UUID userId);

  List<Payment> findByDriverId(UUID driverId);

  @Query("SELECT p FROM Payment p WHERE p.paymentStatus = com.porter.common.enums.PaymentStatus.FAILED " +
      "AND p.retryCount < p.maxRetries " +
      "AND (p.nextRetryAt IS NULL OR p.nextRetryAt <= CURRENT_TIMESTAMP)")
  List<Payment> findPaymentsReadyForRetry();

  // ─── ANALYTICS ───

  long countByPaymentStatus(PaymentStatus status);

  @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.paymentStatus = :status")
  Double sumAmountByPaymentStatus(@Param("status") PaymentStatus status);
}
