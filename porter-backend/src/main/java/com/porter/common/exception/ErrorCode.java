package com.porter.common.exception;

/**
 * Centralized error codes for all exceptions.
 * Frontend can use these codes to show appropriate messages.
 */
public enum ErrorCode {
  // Ride Errors
  RIDE_NOT_FOUND("RIDE_NOT_FOUND", "Ride not found"),
  RIDE_ALREADY_ASSIGNED("RIDE_ALREADY_ASSIGNED", "This ride has already been assigned to another driver"),
  RIDE_NOT_IN_SEARCHING_STATE("RIDE_NOT_IN_SEARCHING_STATE", "Ride is no longer available"),
  INVALID_RIDE_STATUS_TRANSITION("INVALID_RIDE_STATUS_TRANSITION", "Invalid action for current ride status"),
  RIDE_COMPLETION_FAILED("RIDE_COMPLETION_FAILED", "Failed to complete ride"),

  // OTP Errors
  INVALID_OTP("INVALID_OTP", "Invalid OTP. Please enter the correct OTP"),
  OTP_NOT_GENERATED("OTP_NOT_GENERATED", "No OTP generated for this ride"),

  // Driver Errors
  DRIVER_NOT_ASSIGNED("DRIVER_NOT_ASSIGNED", "You are not assigned to this ride"),
  DRIVER_NOT_FOUND("DRIVER_NOT_FOUND", "Driver profile not found"),
  INVALID_DRIVER_CREDENTIALS("INVALID_DRIVER_CREDENTIALS", "Invalid driver credentials"),

  // User Errors
  USER_NOT_FOUND("USER_NOT_FOUND", "User not found"),
  UNAUTHORIZED_ACCESS("UNAUTHORIZED_ACCESS", "You do not have permission to access this resource"),
  INVALID_CREDENTIALS("INVALID_CREDENTIALS", "Invalid email or password"),

  // Payment Errors
  PAYMENT_PROCESSING_FAILED("PAYMENT_PROCESSING_FAILED", "Payment processing failed"),
  BILL_NOT_PENDING("BILL_NOT_PENDING", "Bill is not pending confirmation"),

  // Validation Errors
  INVALID_REQUEST("INVALID_REQUEST", "Invalid request parameters"),
  VALIDATION_FAILED("VALIDATION_FAILED", "Validation failed"),

  // Rate Limit Errors
  TOO_MANY_REQUESTS("TOO_MANY_REQUESTS", "Too many requests. Please try again later"),

  // General Errors
  INTERNAL_SERVER_ERROR("INTERNAL_SERVER_ERROR", "An unexpected error occurred. Please try again"),
  RESOURCE_NOT_FOUND("RESOURCE_NOT_FOUND", "Resource not found");

  private final String code;
  private final String defaultMessage;

  ErrorCode(String code, String defaultMessage) {
    this.code = code;
    this.defaultMessage = defaultMessage;
  }

  public String getCode() {
    return code;
  }

  public String getDefaultMessage() {
    return defaultMessage;
  }
}
