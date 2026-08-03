package com.porter.common.exception;

public class BadRequestException extends BaseException {
  public BadRequestException(String message) {
    super(ErrorCode.INVALID_REQUEST, message);
  }

  public BadRequestException(ErrorCode errorCode) {
    super(errorCode);
  }

  public BadRequestException(ErrorCode errorCode, String customMessage) {
    super(errorCode, customMessage);
  }
}
