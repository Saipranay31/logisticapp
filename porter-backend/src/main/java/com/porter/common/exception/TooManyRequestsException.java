package com.porter.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.TOO_MANY_REQUESTS)
public class TooManyRequestsException extends BaseException {
  public TooManyRequestsException(String message) {
    super(ErrorCode.TOO_MANY_REQUESTS, message);
  }

  public TooManyRequestsException(ErrorCode errorCode) {
    super(errorCode);
  }

  public TooManyRequestsException(ErrorCode errorCode, String customMessage) {
    super(errorCode, customMessage);
  }
}
