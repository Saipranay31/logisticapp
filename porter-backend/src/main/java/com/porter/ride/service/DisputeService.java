package com.porter.ride.service;

import com.porter.common.enums.RideStatus;
import com.porter.common.exception.BadRequestException;
import com.porter.common.exception.ResourceNotFoundException;
import com.porter.ride.entity.Ride;
import com.porter.ride.entity.RideDispute;
import com.porter.ride.repository.RideDisputeRepository;
import com.porter.ride.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DisputeService {

  private final RideDisputeRepository disputeRepository;
  private final RideRepository rideRepository;

  @Transactional
  public RideDispute createDispute(UUID userId, UUID rideId, String reason, String description) {
    Ride ride = rideRepository.findById(rideId)
        .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

    if (ride.getStatus() != RideStatus.COMPLETED) {
      throw new BadRequestException("Can only dispute completed rides");
    }

    if (!ride.getUserId().equals(userId)) {
      throw new BadRequestException("You cannot dispute this ride");
    }

    if (disputeRepository.findByRideId(rideId).isPresent()) {
      throw new BadRequestException("Dispute already exists for this ride");
    }

    RideDispute dispute = RideDispute.builder()
        .rideId(rideId)
        .userId(userId)
        .reason(reason)
        .description(description)
        .status("OPEN")
        .build();

    dispute = disputeRepository.save(dispute);
    log.info("Dispute created for ride {} by user {} - Reason: {}", rideId, userId, reason);
    return dispute;
  }

  public Optional<RideDispute> getDisputeByRide(UUID rideId) {
    return disputeRepository.findByRideId(rideId);
  }

  public List<RideDispute> getUserDisputes(UUID userId) {
    return disputeRepository.findByUserId(userId);
  }

  public List<RideDispute> getAllDisputes() {
    return disputeRepository.findAllByOrderByCreatedAtDesc();
  }

  public List<RideDispute> getOpenDisputes() {
    return disputeRepository.findByStatusOrderByCreatedAtDesc("OPEN");
  }

  @Transactional
  public RideDispute resolveDispute(UUID disputeId, boolean approve, String adminNotes, Double refundAmount) {
    RideDispute dispute = disputeRepository.findById(disputeId)
        .orElseThrow(() -> new ResourceNotFoundException("Dispute not found"));

    dispute.setStatus(approve ? "APPROVED" : "REJECTED");
    dispute.setAdminNotes(adminNotes);
    dispute.setRefundAmount(approve ? refundAmount : null);
    dispute.setResolvedAt(LocalDateTime.now());

    log.info("Dispute {} {} - Notes: {}", disputeId, approve ? "APPROVED" : "REJECTED", adminNotes);
    return disputeRepository.save(dispute);
  }
}
