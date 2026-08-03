package com.porter.payment.service;

import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

/**
 * Razorpay payment gateway integration.
 * Place your API keys in application.yml under razorpay.key-id and
 * razorpay.key-secret.
 */
@Service
@Slf4j
public class RazorpayService {

  @Value("${razorpay.key-id:}")
  private String keyId;

  @Value("${razorpay.key-secret:}")
  private String keySecret;

  /**
   * Create a Razorpay order for the given amount (in paise).
   * Returns orderId, amount, currency, and key.
   */
  public Map<String, Object> createOrder(double amountInRupees, String receiptId) {
    Map<String, Object> result = new HashMap<>();

    if (keyId.isEmpty() || keySecret.isEmpty()) {
      // Fallback: return mock order for testing when keys aren't configured
      log.warn("Razorpay keys not configured. Returning mock order.");
      result.put("orderId", "order_mock_" + System.currentTimeMillis());
      result.put("amount", (int) (amountInRupees * 100));
      result.put("currency", "INR");
      result.put("keyId", "rzp_test_mock");
      result.put("status", "created");
      return result;
    }

    try {
      com.razorpay.RazorpayClient client = new com.razorpay.RazorpayClient(keyId, keySecret);

      JSONObject orderRequest = new JSONObject();
      orderRequest.put("amount", (int) (amountInRupees * 100)); // Amount in paise
      orderRequest.put("currency", "INR");
      orderRequest.put("receipt", receiptId);
      orderRequest.put("payment_capture", 1); // Auto capture

      com.razorpay.Order order = client.orders.create(orderRequest);

      result.put("orderId", order.get("id"));
      result.put("amount", order.get("amount"));
      result.put("currency", order.get("currency"));
      result.put("keyId", keyId);
      result.put("status", order.get("status"));

      log.info("Razorpay order created: {} for ₹{}", order.get("id"), amountInRupees);
    } catch (Exception e) {
      log.error("Razorpay order creation failed: {}", e.getMessage());
      throw new RuntimeException("Payment order creation failed: " + e.getMessage());
    }

    return result;
  }

  /**
   * Verify Razorpay payment signature.
   */
  public boolean verifyPayment(String orderId, String paymentId, String signature) {
    if (keySecret.isEmpty()) {
      log.warn("Razorpay keys not configured. Skipping verification.");
      return true; // Mock mode
    }

    try {
      String data = orderId + "|" + paymentId;
      String generatedSignature = com.razorpay.Utils.getHash(data, keySecret);
      return generatedSignature.equals(signature);
    } catch (Exception e) {
      log.error("Razorpay signature verification failed: {}", e.getMessage());
      return false;
    }
  }
}
