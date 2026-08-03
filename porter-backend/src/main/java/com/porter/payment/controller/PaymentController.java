package com.porter.payment.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.payment.entity.Payment;
import com.porter.payment.entity.PaymentRetryHistory;
import com.porter.payment.repository.PaymentRepository;
import com.porter.payment.service.PaymentRetryService;
import com.porter.payment.service.PaymentService;
import com.porter.payment.service.RazorpayService;
import com.porter.ride.entity.Ride;
import com.porter.ride.repository.RideRepository;
import com.porter.common.enums.PaymentStatus;
import com.porter.common.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {

  private final PaymentService paymentService;
  private final RazorpayService razorpayService;
  private final PaymentRetryService paymentRetryService;
  private final RideRepository rideRepository;
  private final PaymentRepository paymentRepository;

  @GetMapping("/user")
  public ResponseEntity<ApiResponse<List<Payment>>> getUserPayments(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(paymentService.getUserPayments(userId)));
  }

  @GetMapping("/driver")
  public ResponseEntity<ApiResponse<List<Payment>>> getDriverPayments(Authentication auth) {
    UUID driverId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(paymentService.getDriverPayments(driverId)));
  }

  /**
   * Create Razorpay order for a ride.
   * POST /api/payments/create-order
   */
  @PostMapping("/create-order")
  public ResponseEntity<ApiResponse<Map<String, Object>>> createOrder(
      Authentication auth, @RequestBody Map<String, Object> body) {
    UUID rideId = UUID.fromString((String) body.get("rideId"));
    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    double amount = ride.getEstimatedFare() != null ? ride.getEstimatedFare() : 0;
    Map<String, Object> order = razorpayService.createOrder(amount, rideId.toString());

    return ResponseEntity.ok(ApiResponse.success(order));
  }

  /**
   * Verify Razorpay payment after completion.
   * POST /api/payments/verify
   */
  @PostMapping("/verify")
  public ResponseEntity<ApiResponse<Map<String, Object>>> verifyPayment(
      @RequestBody Map<String, String> body) {
    String orderId = body.get("razorpay_order_id");
    String paymentId = body.get("razorpay_payment_id");
    String signature = body.get("razorpay_signature");
    UUID rideId = UUID.fromString(body.get("rideId"));

    boolean verified = razorpayService.verifyPayment(orderId, paymentId, signature);

    if (verified) {
      // Update payment record
      paymentRepository.findByRideId(rideId).ifPresent(payment -> {
        payment.setRazorpayOrderId(orderId);
        payment.setRazorpayPaymentId(paymentId);
        payment.setRazorpaySignature(signature);
        payment.setPaymentStatus(PaymentStatus.COMPLETED);
        paymentRepository.save(payment);
      });

      return ResponseEntity.ok(ApiResponse.success(Map.of(
          "verified", true, "message", "Payment verified successfully")));
    }

    return ResponseEntity.ok(ApiResponse.success(Map.of(
        "verified", false, "message", "Payment verification failed")));
  }

  // ─── PAYMENT RETRY ───

  @PostMapping("/admin/{paymentId}/retry")
  public ResponseEntity<ApiResponse<Map<String, Object>>> retryPayment(
      @PathVariable UUID paymentId) {
    paymentRetryService.manualRetry(paymentId);
    return ResponseEntity.ok(ApiResponse.success(Map.of(
        "paymentId", paymentId,
        "status", "RETRY_SCHEDULED",
        "message", "Payment retry scheduled")));
  }

  @GetMapping("/{paymentId}/retry-history")
  public ResponseEntity<ApiResponse<List<PaymentRetryHistory>>> getRetryHistory(
      @PathVariable UUID paymentId) {
    return ResponseEntity.ok(ApiResponse.success(
        paymentRetryService.getRetryHistory(paymentId)));
  }
}
