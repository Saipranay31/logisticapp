package com.porter.common.exception;

/**
 * Base exception class with error code support.
 * All custom exceptions should extend this.
 */
public class BaseException extends RuntimeException {
  private final ErrorCode errorCode;

  public BaseException(ErrorCode errorCode) {
    super(errorCode.getDefaultMessage());
    this.errorCode = errorCode;
  }

  public BaseException(ErrorCode errorCode, String customMessage) {
    super(customMessage);
    this.errorCode = errorCode;
  }

  public ErrorCode getErrorCode() {
    return errorCode;
  }
}
