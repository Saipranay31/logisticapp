package com.porter.common.exception;

public class ResourceNotFoundException extends BaseException {
  public ResourceNotFoundException(String message) {
    super(ErrorCode.RESOURCE_NOT_FOUND, message);
  }

  public ResourceNotFoundException(ErrorCode errorCode) {
    super(errorCode);
  }

  public ResourceNotFoundException(ErrorCode errorCode, String customMessage) {
    super(errorCode, customMessage);
  }
}
