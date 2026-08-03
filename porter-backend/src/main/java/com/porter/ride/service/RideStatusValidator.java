package com.porter.ride.service;

import com.porter.common.enums.RideStatus;
import com.porter.common.exception.RideAlreadyAssignedException;

import java.util.Map;
import java.util.Set;

/**
 * Validates ride status transitions to prevent invalid state changes.
 * Throws specific exceptions with user-friendly error messages.
 */
public class RideStatusValidator {

  private static final Map<RideStatus, Set<RideStatus>> VALID_TRANSITIONS = Map.ofEntries(
      Map.entry(RideStatus.REQUESTED, Set.of(RideStatus.SEARCHING, RideStatus.CANCELLED)),
      Map.entry(RideStatus.SEARCHING, Set.of(RideStatus.ASSIGNED, RideStatus.CANCELLED)),
      Map.entry(RideStatus.ASSIGNED, Set.of(RideStatus.ARRIVED, RideStatus.CANCELLED)),
      Map.entry(RideStatus.ARRIVED, Set.of(RideStatus.IN_PROGRESS, RideStatus.CANCELLED)),
      Map.entry(RideStatus.IN_PROGRESS, Set.of(RideStatus.COMPLETED, RideStatus.CANCELLED)),
      Map.entry(RideStatus.COMPLETED, Set.of()),
      Map.entry(RideStatus.CANCELLED, Set.of()));

  /**
   * Validates that a ride can transition from one status to another.
   *
   * @throws RideAlreadyAssignedException if ride is already assigned
   * @throws IllegalStateException for other invalid transitions
   */
  public static void validateTransition(RideStatus from, RideStatus to) {
    Set<RideStatus> allowed = VALID_TRANSITIONS.get(from);
    if (allowed == null || !allowed.contains(to)) {
      // ✅ SPECIFIC ERROR: If trying to assign an already assigned ride
      if (from == RideStatus.ASSIGNED && to == RideStatus.ASSIGNED) {
        throw new RideAlreadyAssignedException();
      }
      throw new IllegalStateException(
          String.format("Cannot transition ride from %s to %s", from, to));
    }
  }
}

