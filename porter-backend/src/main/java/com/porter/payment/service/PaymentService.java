package com.porter.payment.service;

import com.porter.common.enums.PaymentMethod;
import com.porter.common.enums.PaymentStatus;
import com.porter.financial.service.FinancialService;
import com.porter.payment.entity.Payment;
import com.porter.payment.repository.PaymentRepository;
import com.porter.ride.entity.Ride;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {

  private final PaymentRepository paymentRepository;
  private final FinancialService financialService;

  /**
   * Process payment for a completed ride.
   */
  @Transactional
  public Payment processPayment(Ride ride) {
    Payment payment = Payment.builder()
        .rideId(ride.getId())
        .userId(ride.getUserId())
        .driverId(ride.getDriverId())
        .amount(ride.getActualFare())
        .paymentMethod(PaymentMethod.CASH)
        .paymentStatus(PaymentStatus.COMPLETED)
        .build();

    payment = paymentRepository.save(payment);

    // Record financial entries
    financialService.recordTransaction(ride);

    log.info("Payment of ₹{} processed for ride {}", ride.getActualFare(), ride.getId());
    return payment;
  }

  /**
   * Process payment asynchronously (non-blocking).
   * 🔴 FIX #3: Called after bill confirmation to avoid blocking user
   */
  @Async
  @Transactional
  public void processPaymentAsync(Ride ride) {
    try {
      Thread.sleep(500); // Small delay to ensure ride update is persisted
      processPayment(ride);
      log.info("✅ Async payment processed successfully for ride {}", ride.getId());
    } catch (Exception e) {
      log.error("❌ Async payment failed for ride {}: {}", ride.getId(), e.getMessage(), e);
    }
  }

  public List<Payment> getUserPayments(UUID userId) {
    return paymentRepository.findByUserId(userId);
  }

  public List<Payment> getDriverPayments(UUID driverId) {
    return paymentRepository.findByDriverId(driverId);
  }
}
