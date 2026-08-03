package com.porter.matching.service;

import com.porter.common.enums.RideStatus;
import com.porter.ride.repository.RideRepository;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Handles ride status updates with proper transaction management.
 * Extracted to separate service to enable @Transactional in async contexts
 * without causing circular reference issues.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RideStatusService {

  private final RideRepository rideRepository;
  private final EntityManager entityManager;

  /**
   * Update ride status with a new transaction and explicit cache clear.
   * Uses REQUIRES_NEW to force a new transaction, independent of any parent.
   * Explicitly clears persistence context to ensure fresh reads on next query.
   * This allows the update to be committed even when called from @Async methods.
   */
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void updateRideStatusSearching(UUID rideId) {
    rideRepository.updateRideStatus(rideId, RideStatus.SEARCHING);
    // ✅ CRITICAL: Explicitly clear the persistence context to remove cached entities
    // This forces the next query (in acceptRide) to read from database, not cache
    entityManager.flush();    // ← Ensure SQL is executed
    entityManager.clear();    // ← Clear cache to remove stale entities
    log.debug("🧹 Persistence context cleared after status update");
  }
}
