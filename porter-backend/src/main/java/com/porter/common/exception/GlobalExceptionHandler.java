package com.porter.common.exception;

import com.porter.common.dto.ApiResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import lombok.extern.slf4j.Slf4j;

import java.util.HashMap;
import java.util.Map;

/**
 * Global exception handler for consistent error responses with error codes.
 * Frontend uses errorCode to show appropriate user-friendly messages.
 */
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

  /**
   * Handle BaseException and its subclasses (RideAlreadyAssignedException, etc.)
   */
  @ExceptionHandler(BaseException.class)
  public ResponseEntity<ApiResponse<Void>> handleBaseException(BaseException ex) {
    ErrorCode errorCode = ex.getErrorCode();
    log.warn("⚠️ {} - {}", errorCode.getCode(), ex.getMessage());

    HttpStatus httpStatus = mapErrorCodeToHttpStatus(errorCode);
    return ResponseEntity.status(httpStatus)
        .body(ApiResponse.error(errorCode.getCode(), ex.getMessage()));
  }

  @ExceptionHandler(ResourceNotFoundException.class)
  public ResponseEntity<ApiResponse<Void>> handleNotFound(ResourceNotFoundException ex) {
    log.warn("⚠️ NOT_FOUND - {}", ex.getMessage());
    return ResponseEntity.status(HttpStatus.NOT_FOUND)
        .body(ApiResponse.error(ex.getErrorCode().getCode(), ex.getMessage()));
  }

  @ExceptionHandler(BadRequestException.class)
  public ResponseEntity<ApiResponse<Void>> handleBadRequest(BadRequestException ex) {
    log.warn("⚠️ BAD_REQUEST - {}", ex.getMessage());
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(ApiResponse.error(ex.getErrorCode().getCode(), ex.getMessage()));
  }

  @ExceptionHandler(UnauthorizedException.class)
  public ResponseEntity<ApiResponse<Void>> handleUnauthorized(UnauthorizedException ex) {
    log.warn("⚠️ UNAUTHORIZED - {}", ex.getMessage());
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
        .body(ApiResponse.error(ex.getErrorCode().getCode(), ex.getMessage()));
  }

  @ExceptionHandler(ConflictException.class)
  public ResponseEntity<ApiResponse<Void>> handleConflict(ConflictException ex) {
    log.warn("⚠️ CONFLICT - {}", ex.getMessage());
    return ResponseEntity.status(HttpStatus.CONFLICT)
        .body(ApiResponse.error(ex.getErrorCode().getCode(), ex.getMessage()));
  }

  @ExceptionHandler(RideAlreadyAssignedException.class)
  public ResponseEntity<ApiResponse<Void>> handleRideAlreadyAssigned(RideAlreadyAssignedException ex) {
    log.warn("⚠️ RIDE_ALREADY_ASSIGNED - {}", ex.getMessage());
    return ResponseEntity.status(HttpStatus.CONFLICT)
        .body(ApiResponse.error(ex.getErrorCode().getCode(), ex.getMessage()));
  }

  @ExceptionHandler(TooManyRequestsException.class)
  public ResponseEntity<ApiResponse<Void>> handleTooManyRequests(TooManyRequestsException ex) {
    log.warn("⚠️ TOO_MANY_REQUESTS - {}", ex.getMessage());
    return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
        .body(ApiResponse.error(ex.getErrorCode().getCode(), ex.getMessage()));
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ApiResponse<Map<String, String>>> handleValidation(MethodArgumentNotValidException ex) {
    Map<String, String> errors = new HashMap<>();
    ex.getBindingResult().getAllErrors().forEach(error -> {
      String field = ((FieldError) error).getField();
      String message = error.getDefaultMessage();
      errors.put(field, message);
    });
    log.warn("⚠️ VALIDATION_FAILED - {}", errors);
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(ApiResponse.<Map<String, String>>builder()
            .success(false)
            .errorCode(ErrorCode.VALIDATION_FAILED.getCode())
            .message("Validation failed")
            .data(errors)
            .build());
  }

  /**
   * Catch-all handler for unexpected exceptions
   */
  @ExceptionHandler(Exception.class)
  public ResponseEntity<ApiResponse<Void>> handleGeneral(Exception ex) {
    log.error("❌ INTERNAL_SERVER_ERROR - Unexpected exception", ex);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(ApiResponse.error(
            ErrorCode.INTERNAL_SERVER_ERROR.getCode(),
            ErrorCode.INTERNAL_SERVER_ERROR.getDefaultMessage()
        ));
  }

  /**
   * Map ErrorCode to appropriate HTTP status
   */
  private HttpStatus mapErrorCodeToHttpStatus(ErrorCode errorCode) {
    return switch (errorCode) {
      case RESOURCE_NOT_FOUND, RIDE_NOT_FOUND, DRIVER_NOT_FOUND, USER_NOT_FOUND:
        yield HttpStatus.NOT_FOUND;
      case UNAUTHORIZED_ACCESS, INVALID_CREDENTIALS:
        yield HttpStatus.UNAUTHORIZED;
      case INVALID_REQUEST, INVALID_OTP, INVALID_RIDE_STATUS_TRANSITION:
        yield HttpStatus.BAD_REQUEST;
      case RIDE_ALREADY_ASSIGNED:
        yield HttpStatus.CONFLICT;
      case TOO_MANY_REQUESTS:
        yield HttpStatus.TOO_MANY_REQUESTS;
      default:
        yield HttpStatus.INTERNAL_SERVER_ERROR;
    };
  }
}

