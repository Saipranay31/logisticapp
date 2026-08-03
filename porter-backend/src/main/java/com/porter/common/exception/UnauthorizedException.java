package com.porter.common.exception;

public class UnauthorizedException extends BaseException {
  public UnauthorizedException(String message) {
    super(ErrorCode.UNAUTHORIZED_ACCESS, message);
  }

  public UnauthorizedException(ErrorCode errorCode) {
    super(errorCode);
  }

  public UnauthorizedException(ErrorCode errorCode, String customMessage) {
    super(errorCode, customMessage);
  }
}
