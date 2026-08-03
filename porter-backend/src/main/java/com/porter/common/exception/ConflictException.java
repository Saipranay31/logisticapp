package com.porter.common.exception;

public class ConflictException extends BaseException {
  public ConflictException(String message) {
    super(ErrorCode.INVALID_RIDE_STATUS_TRANSITION, message);
  }

  public ConflictException(ErrorCode errorCode) {
    super(errorCode);
  }

  public ConflictException(ErrorCode errorCode, String customMessage) {
    super(errorCode, customMessage);
  }
}
