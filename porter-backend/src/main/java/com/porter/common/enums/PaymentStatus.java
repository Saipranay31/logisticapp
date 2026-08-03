package com.porter.common.enums;

/**
 * Payment statuses.
 * PENDING: Bill shown, waiting for user confirmation
 * CONFIRMED: User confirmed bill, payment processing initiated
 * COMPLETED: Payment successfully processed
 * FAILED: Payment failed
 * REFUNDED: Payment refunded
 */
public enum PaymentStatus {
  PENDING,
  CONFIRMED,
  COMPLETED,
  FAILED,
  REFUNDED
}
