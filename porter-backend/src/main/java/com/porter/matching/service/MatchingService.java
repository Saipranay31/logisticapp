package com.porter.matching.service;

import com.porter.common.enums.RideStatus;
import com.porter.location.service.LocationService;
import com.porter.notification.service.NotificationService;
import com.porter.ride.entity.Ride;
import com.porter.ride.repository.RideRepository;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.driver.repository.DriverVehicleRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;

/**
 * Matching / Dispatch service.
 *
 * Improvements applied:
 *  Fix 1+2 — Single WebSocket notification per driver, only for matching vehicle type.
 *  Fix 3   — Auto-cancel broadcasts a proper DTO map, not the raw Ride entity.
 *  Fix 5   — Already-notified drivers are skipped across the entire 10-minute search window.
 *  Fix 6   — Acceptance polling uses a shared ScheduledExecutorService instead of
 *             blocking Thread.sleep on every matching thread.
 *  Fix 7   — Time-based cycling: [5km → 10km → 15km] repeats for 10 minutes then auto-cancel.
 *             Searching status (radius + time remaining) is broadcast to user on each ring.
 */
@Service
@Slf4j
public class MatchingService {

  private final LocationService locationService;
  private final RideRepository rideRepository;
  private final NotificationService notificationService;
  private final SimpMessagingTemplate messagingTemplate;
  private final DriverProfileRepository driverProfileRepository;
  private final DriverVehicleRepository driverVehicleRepository;
  private final RideStatusService rideStatusService;
  private final ScheduledExecutorService matchingScheduler;

  public MatchingService(
      LocationService locationService,
      RideRepository rideRepository,
      NotificationService notificationService,
      SimpMessagingTemplate messagingTemplate,
      DriverProfileRepository driverProfileRepository,
      DriverVehicleRepository driverVehicleRepository,
      RideStatusService rideStatusService,
      @Qualifier("matchingScheduler") ScheduledExecutorService matchingScheduler) {
    this.locationService = locationService;
    this.rideRepository = rideRepository;
    this.notificationService = notificationService;
    this.messagingTemplate = messagingTemplate;
    this.driverProfileRepository = driverProfileRepository;
    this.driverVehicleRepository = driverVehicleRepository;
    this.rideStatusService = rideStatusService;
    this.matchingScheduler = matchingScheduler;
  }

  /** Base search radius — rings are 1×, 2×, 3× of this value. */
  @Value("${porter.matching.search-radius-km:5.0}")
  private double searchRadiusKm;

  /** Total time (minutes) to keep searching before auto-cancel. */
  @Value("${porter.matching.total-search-minutes:10}")
  private int totalSearchMinutes;

  /** Radius ring multipliers: 1× = 5km, 2× = 10km, 3× = 15km */
  private static final double[] RADIUS_MULTIPLIERS = {1.0, 2.0, 3.0};

  /**
   * Asynchronously find a driver for the given ride.
   *
   * Fix 7: Cycles through [5km → 10km → 15km] rings, restarting from 5km
   * after each full cycle, for a total of {@code totalSearchMinutes} minutes.
   * Only NEW drivers (not yet notified) are contacted.  The same Set tracks
   * all notified drivers across the entire window so no one is spammed.
   */
  @Async("matchingExecutor")
  public void findDriverForRide(Ride ride) {
    UUID rideId = ride.getId();
    log.info("🔍 findDriverForRide: rideId={}, vehicleType={}", rideId, ride.getVehicleType());

    rideStatusService.updateRideStatusSearching(rideId);
    log.info("✅ SEARCHING status committed for ride {}", rideId);

    // Brief delay to ensure the createRide transaction has fully committed before
    // we start reading ride status from DB on the async thread.
    try { Thread.sleep(300); } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return;
    }

    Set<UUID> notifiedDrivers = ConcurrentHashMap.newKeySet();

    long deadlineMs = System.currentTimeMillis() + (long) totalSearchMinutes * 60_000L;
    int cycle = 0;

    outer:
    while (System.currentTimeMillis() < deadlineMs) {

      for (int ring = 0; ring < RADIUS_MULTIPLIERS.length; ring++) {
        if (System.currentTimeMillis() >= deadlineMs) break outer;

        double radius = searchRadiusKm * RADIUS_MULTIPLIERS[ring];
        long remainingMs = deadlineMs - System.currentTimeMillis();
        int remainingSec = (int) (remainingMs / 1000);

        log.info("🔍 Cycle {} Ring {}: {}km, {}s remaining for ride {}",
            cycle + 1, ring + 1, radius, remainingSec, rideId);

        // Broadcast searching status to user so they see radius + countdown
        broadcastSearchingUpdate(ride.getUserId(), rideId, radius, remainingSec, cycle + 1, ring + 1);

        // Find nearby drivers and notify new ones
        List<String> nearbyDriverIds = locationService.findNearbyDrivers(
            ride.getPickupLatitude(), ride.getPickupLongitude(), radius);

        if (!nearbyDriverIds.isEmpty()) {
          List<String> candidates = filterAvailableDrivers(nearbyDriverIds, notifiedDrivers, rideId);
          log.info("📡 Cycle {} Ring {}: {} nearby, {} new candidates ({} already notified)",
              cycle + 1, ring + 1, nearbyDriverIds.size(), candidates.size(), notifiedDrivers.size());
          notifyMatchingDrivers(candidates, ride, rideId, notifiedDrivers);
        } else {
          log.warn("No drivers within {}km for ride {} (cycle {} ring {})",
              radius, rideId, cycle + 1, ring + 1);
        }

        // Wait up to 30s (or until deadline) for acceptance
        int pollSec = (int) Math.min(30, (deadlineMs - System.currentTimeMillis()) / 1000);
        if (pollSec > 0) {
          boolean accepted = waitForAcceptance(rideId, pollSec);
          if (accepted) {
            log.info("✅ Ride {} accepted (cycle {} ring {})", rideId, cycle + 1, ring + 1);
            return;
          }
        }

        // After waiting, check if user cancelled — do this AFTER acceptance wait,
        // not before notifying drivers, to avoid a TX-timing false-positive exit.
        Ride fresh = rideRepository.findById(rideId).orElse(null);
        if (fresh == null || fresh.getStatus() != RideStatus.SEARCHING) {
          log.info("⏹️ Ride {} no longer SEARCHING (status={}) — exit matching loop",
              rideId, fresh != null ? fresh.getStatus() : "NOT_FOUND");
          return;
        }

        // Brief gap between rings (skip for last ring in cycle)
        if (ring < RADIUS_MULTIPLIERS.length - 1 && System.currentTimeMillis() < deadlineMs) {
          try {
            Thread.sleep(1000);
          } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return;
          }
        }
      }

      cycle++;

      // Short pause between cycles before restarting at 5km
      if (System.currentTimeMillis() < deadlineMs) {
        try {
          Thread.sleep(2000);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          return;
        }
      }
    }

    // 10 minutes elapsed with no acceptance — auto-cancel
    log.warn("No driver accepted ride {} after {}min search", rideId, totalSearchMinutes);
    Ride finalRide = rideRepository.findById(rideId).orElse(null);
    if (finalRide != null && finalRide.getStatus() == RideStatus.SEARCHING) {
      finalRide.setStatus(RideStatus.CANCELLED);
      finalRide.setCancelledBy("SYSTEM");
      rideRepository.save(finalRide);

      notificationService.sendNotification(ride.getUserId(),
          "No Drivers Available",
          "No drivers are available right now. Please try again in a few minutes.",
          "RIDE_UPDATE");

      // Fix 3: Proper DTO map (not raw Ride entity)
      messagingTemplate.convertAndSend(
          "/topic/user/" + ride.getUserId() + "/ride",
          buildCancelledDto(finalRide));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /**
   * Notify all matching-vehicle candidates that haven't been contacted yet.
   * Each driver receives exactly ONE notification across the whole search window.
   */
  private void notifyMatchingDrivers(List<String> candidates, Ride ride,
                                     UUID rideId, Set<UUID> notifiedDrivers) {
    for (String driverIdStr : candidates) {
      try {
        UUID driverId = UUID.fromString(driverIdStr);

        // Fix 1+2: Check vehicle type BEFORE sending ANY notification.
        var driverProfile = driverProfileRepository.findByUserId(driverId);
        if (driverProfile.isPresent()) {
          var activeVehicle = driverVehicleRepository
              .findByDriverProfileIdAndIsActive(driverProfile.get().getId(), true);
          if (activeVehicle.isPresent() &&
              activeVehicle.get().getVehicleType().name()
                  .equalsIgnoreCase(ride.getVehicleType())) {

            notificationService.sendRideRequestNotification(
                driverId, rideId.toString(),
                ride.getPickupAddress(), ride.getDropAddress(),
                ride.getEstimatedFare(), ride.getEstimatedDistanceKm(),
                ride.getPickupLatitude(), ride.getPickupLongitude(),
                ride.getDropLatitude(), ride.getDropLongitude());

            notifiedDrivers.add(driverId);
            log.info("✅ Notified driver {} for ride {}", driverId, rideId);
          } else {
            log.info("❌ Vehicle mismatch – driver {} has {}, ride needs {}",
                driverId,
                activeVehicle.isPresent() ? activeVehicle.get().getVehicleType() : "UNKNOWN",
                ride.getVehicleType());
          }
        }
      } catch (Exception e) {
        log.error("Failed to notify driver {}: {}", driverIdStr, e.getMessage());
      }
    }
  }

  /**
   * Fix 7: Broadcast the current searching state to the user's ride channel so
   * the user app can display "Searching (10km) · 8:30 remaining" in real time.
   */
  private void broadcastSearchingUpdate(UUID userId, UUID rideId,
                                        double radius, int remainingSec,
                                        int cycle, int ring) {
    try {
      Map<String, Object> update = new HashMap<>();
      update.put("id", rideId.toString());
      update.put("status", "SEARCHING");
      update.put("searchRadiusKm", radius);
      update.put("searchTimeRemainingSeconds", remainingSec);
      update.put("searchCycle", cycle);
      update.put("searchRing", ring);
      messagingTemplate.convertAndSend("/topic/user/" + userId + "/ride", update);
      log.debug("📡 Searching update → user {}: {}km, {}s remaining", userId, radius, remainingSec);
    } catch (Exception e) {
      log.warn("Could not broadcast searching update for ride {}: {}", rideId, e.getMessage());
    }
  }

  /**
   * Fix 6: Schedule per-second DB checks on the shared scheduler, so the
   * matching thread only needs to await a Future instead of calling Thread.sleep.
   */
  private boolean waitForAcceptance(UUID rideId, int timeoutSeconds) {
    if (timeoutSeconds <= 0) return false;

    CompletableFuture<Boolean> future = new CompletableFuture<>();
    AtomicReference<ScheduledFuture<?>> checkRef = new AtomicReference<>();

    ScheduledFuture<?> checkTask = matchingScheduler.scheduleAtFixedRate(() -> {
      try {
        Ride r = rideRepository.findById(rideId).orElse(null);
        if (r != null && r.getStatus() == RideStatus.ASSIGNED) {
          future.complete(true);
          ScheduledFuture<?> t = checkRef.get();
          if (t != null) t.cancel(false);
        }
      } catch (Exception e) {
        log.warn("Poll error for ride {}: {}", rideId, e.getMessage());
      }
    }, 1, 1, TimeUnit.SECONDS);

    checkRef.set(checkTask);

    // Auto-resolve with false at timeout
    matchingScheduler.schedule(() -> {
      if (!future.isDone()) {
        future.complete(false);
        checkTask.cancel(false);
      }
    }, timeoutSeconds, TimeUnit.SECONDS);

    try {
      return future.get(timeoutSeconds + 2, TimeUnit.SECONDS);
    } catch (TimeoutException e) {
      checkTask.cancel(false);
      return false;
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      checkTask.cancel(false);
      return false;
    } catch (ExecutionException e) {
      log.warn("waitForAcceptance error for ride {}: {}", rideId, e.getMessage());
      return false;
    }
  }

  /**
   * Fix 5: Filter drivers who are available AND not already notified.
   */
  private List<String> filterAvailableDrivers(List<String> driverIds,
                                               Set<UUID> alreadyNotified,
                                               UUID rideId) {
    return driverIds.stream()
        .filter(driverIdStr -> {
          try {
            UUID driverId = UUID.fromString(driverIdStr);

            // Skip drivers already notified during this search window
            if (alreadyNotified.contains(driverId)) {
              log.debug("⏭️ Skip driver {} – already notified for ride {}", driverId, rideId);
              return false;
            }

            // Skip drivers with an active ride
            var activeRides = rideRepository.findByDriverIdAndStatusIn(driverId, List.of(
                RideStatus.ASSIGNED, RideStatus.ARRIVED, RideStatus.IN_PROGRESS));
            if (!activeRides.isEmpty()) {
              log.info("⏭️ Skip driver {} – has {} active ride(s)", driverId, activeRides.size());
              return false;
            }
            return true;
          } catch (Exception e) {
            log.warn("Error filtering driver {}: {}", driverIdStr, e.getMessage());
            return false;
          }
        })
        .collect(Collectors.toList());
  }

  /**
   * Fix 3: Build a minimal DTO-shaped map for the cancelled-ride broadcast
   * so the user app receives the same field names it uses for all ride updates.
   */
  private Map<String, Object> buildCancelledDto(Ride ride) {
    Map<String, Object> dto = new HashMap<>();
    dto.put("id", ride.getId().toString());
    dto.put("status", "CANCELLED");
    dto.put("cancelledBy", "SYSTEM");
    dto.put("userId", ride.getUserId() != null ? ride.getUserId().toString() : null);
    dto.put("pickupAddress", ride.getPickupAddress());
    dto.put("dropAddress", ride.getDropAddress());
    dto.put("pickupLatitude", ride.getPickupLatitude());
    dto.put("pickupLongitude", ride.getPickupLongitude());
    dto.put("dropLatitude", ride.getDropLatitude());
    dto.put("dropLongitude", ride.getDropLongitude());
    dto.put("estimatedFare", ride.getEstimatedFare());
    dto.put("estimatedDistanceKm", ride.getEstimatedDistanceKm());
    dto.put("vehicleType", ride.getVehicleType());
    return dto;
  }

  /** Kept for backward compatibility / direct record usage if needed elsewhere. */
  public record RideRequestNotification(
      UUID rideId,
      String pickupAddress,
      String dropAddress,
      Double distanceKm,
      Double estimatedFare,
      String vehicleType) {
  }
}
