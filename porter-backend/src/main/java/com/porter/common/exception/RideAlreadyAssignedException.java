package com.porter.common.exception;

/**
 * Thrown when attempting to accept a ride that's already been assigned.
 */
public class RideAlreadyAssignedException extends BaseException {
  public RideAlreadyAssignedException() {
    super(ErrorCode.RIDE_ALREADY_ASSIGNED);
  }

  public RideAlreadyAssignedException(String customMessage) {
    super(ErrorCode.RIDE_ALREADY_ASSIGNED, customMessage);
  }
}
