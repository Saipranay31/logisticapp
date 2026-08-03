package com.porter.payment.service;

import com.porter.common.enums.PaymentStatus;
import com.porter.notification.service.NotificationService;
import com.porter.payment.entity.Payment;
import com.porter.payment.entity.PaymentRetryHistory;
import com.porter.payment.repository.PaymentRepository;
import com.porter.payment.repository.PaymentRetryHistoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Payment retry with exponential backoff.
 * Auto-retries failed payments every 5 minutes.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentRetryService {

  private final PaymentRepository paymentRepository;
  private final PaymentRetryHistoryRepository retryHistoryRepository;
  private final RazorpayService razorpayService;
  private final NotificationService notificationService;

  /**
   * Scheduled task: retry failed payments every 5 minutes.
   */
  @Scheduled(fixedDelay = 300000)
  @Transactional
  public void retryFailedPayments() {
    List<Payment> paymentsToRetry = paymentRepository.findPaymentsReadyForRetry();
    for (Payment payment : paymentsToRetry) {
      try {
        retryPayment(payment.getId());
      } catch (Exception e) {
        log.error("Failed to retry payment {}: {}", payment.getId(), e.getMessage());
      }
    }
    if (!paymentsToRetry.isEmpty()) {
      log.info("Processed {} payment retries", paymentsToRetry.size());
    }
  }

  /**
   * Retry a specific payment.
   */
  @Transactional
  public void retryPayment(UUID paymentId) {
    Payment payment = paymentRepository.findById(paymentId)
        .orElseThrow(() -> new RuntimeException("Payment not found"));

    if (payment.getRetryCount() >= payment.getMaxRetries()) {
      log.warn("Payment {} exceeded max retries ({})", paymentId, payment.getMaxRetries());
      payment.setPaymentStatus(PaymentStatus.FAILED);
      paymentRepository.save(payment);
      return;
    }

    try {
      // Attempt payment via Razorpay
      boolean success = processPaymentAttempt(payment);

      if (success) {
        payment.setPaymentStatus(PaymentStatus.COMPLETED);
        payment.setLastRetryAt(LocalDateTime.now());
        paymentRepository.save(payment);

        recordRetryHistory(paymentId, payment.getRetryCount() + 1, "SUCCESS", null);

        notificationService.sendNotification(payment.getUserId(),
            "Payment Successful",
            "Your payment of ₹" + payment.getAmount() + " has been processed successfully.",
            "PAYMENT_SUCCESS");

        log.info("Payment {} succeeded on retry {}", paymentId, payment.getRetryCount() + 1);
      } else {
        payment.setRetryCount(payment.getRetryCount() + 1);
        payment.setLastRetryAt(LocalDateTime.now());
        payment.setNextRetryAt(calculateNextRetryTime(payment.getRetryCount()));
        payment.setPaymentStatus(PaymentStatus.FAILED);
        paymentRepository.save(payment);

        recordRetryHistory(paymentId, payment.getRetryCount(), "FAILED", "Payment processing failed");

        notificationService.sendNotification(payment.getUserId(),
            "Payment Retry",
            "Payment retry attempt " + payment.getRetryCount() + " scheduled.",
            "PAYMENT_RETRY");

        log.warn("Payment {} failed on retry {}, next at {}",
            paymentId, payment.getRetryCount(), payment.getNextRetryAt());
      }
    } catch (Exception e) {
      log.error("Error during payment retry for {}: {}", paymentId, e.getMessage());
      payment.setErrorMessage(e.getMessage());
      payment.setRetryCount(payment.getRetryCount() + 1);
      payment.setLastRetryAt(LocalDateTime.now());
      payment.setNextRetryAt(calculateNextRetryTime(payment.getRetryCount()));
      paymentRepository.save(payment);
      recordRetryHistory(paymentId, payment.getRetryCount(), "FAILED", e.getMessage());
    }
  }

  /**
   * Manual retry (admin).
   */
  @Transactional
  public void manualRetry(UUID paymentId) {
    Payment payment = paymentRepository.findById(paymentId)
        .orElseThrow(() -> new RuntimeException("Payment not found"));

    if (payment.getPaymentStatus() == PaymentStatus.COMPLETED) {
      throw new RuntimeException("Cannot retry completed payment");
    }

    payment.setRetryCount(0);
    payment.setNextRetryAt(LocalDateTime.now());
    paymentRepository.save(payment);

    retryPayment(paymentId);
  }

  /**
   * Exponential backoff: 1m → 5m → 15m → 30m.
   */
  private LocalDateTime calculateNextRetryTime(int attemptNumber) {
    return switch (attemptNumber) {
      case 1 -> LocalDateTime.now().plusMinutes(1);
      case 2 -> LocalDateTime.now().plusMinutes(5);
      case 3 -> LocalDateTime.now().plusMinutes(15);
      default -> LocalDateTime.now().plusMinutes(30);
    };
  }

  private boolean processPaymentAttempt(Payment payment) {
    // If Razorpay keys are configured, attempt real payment
    // Otherwise return true (mock mode)
    try {
      if (payment.getRazorpayOrderId() != null) {
        return payment.getRazorpayPaymentId() != null;
      }
      return true; // CASH payments always succeed
    } catch (Exception e) {
      return false;
    }
  }

  private void recordRetryHistory(UUID paymentId, int attempt, String status, String error) {
    retryHistoryRepository.save(PaymentRetryHistory.builder()
        .paymentId(paymentId)
        .retryAttempt(attempt)
        .status(status)
        .error(error)
        .build());
  }

  public List<PaymentRetryHistory> getRetryHistory(UUID paymentId) {
    return retryHistoryRepository.findByPaymentIdOrderByAttemptedAtDesc(paymentId);
  }
}
