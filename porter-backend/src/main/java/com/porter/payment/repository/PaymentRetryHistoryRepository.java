package com.porter.payment.repository;

import com.porter.payment.entity.PaymentRetryHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PaymentRetryHistoryRepository extends JpaRepository<PaymentRetryHistory, UUID> {
  List<PaymentRetryHistory> findByPaymentIdOrderByAttemptedAtDesc(UUID paymentId);

  List<PaymentRetryHistory> findByStatus(String status);
}
