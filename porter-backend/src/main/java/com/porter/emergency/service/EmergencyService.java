package com.porter.emergency.service;

import com.porter.auth.entity.User;
import com.porter.auth.repository.UserRepository;
import com.porter.common.enums.RideStatus;
import com.porter.common.exception.ResourceNotFoundException;
import com.porter.emergency.entity.EmergencyAlert;
import com.porter.emergency.entity.EmergencyContact;
import com.porter.emergency.repository.EmergencyAlertRepository;
import com.porter.emergency.repository.EmergencyContactRepository;
import com.porter.notification.service.NotificationService;
import com.porter.ride.entity.Ride;
import com.porter.ride.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmergencyService {

  private final EmergencyAlertRepository alertRepository;
  private final EmergencyContactRepository contactRepository;
  private final RideRepository rideRepository;
  private final UserRepository userRepository;
  private final NotificationService notificationService;
  private final SimpMessagingTemplate messagingTemplate;

  @Transactional
  public EmergencyAlert triggerSOS(UUID userId, UUID rideId, String alertType,
      String description, Double latitude, Double longitude) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("User not found"));

    EmergencyAlert alert = EmergencyAlert.builder()
        .userId(userId)
        .rideId(rideId)
        .alertType(alertType != null ? alertType : "SOS")
        .description(description)
        .latitude(latitude)
        .longitude(longitude)
        .status("OPEN")
        .policeContacted(true)
        .build();

    alert = alertRepository.save(alert);

    // Cancel ride if ongoing
    if (rideId != null) {
      rideRepository.findById(rideId).ifPresent(ride -> {
        if (ride.getStatus() != RideStatus.COMPLETED && ride.getStatus() != RideStatus.CANCELLED) {
          ride.setStatus(RideStatus.CANCELLED);
          ride.setCancelledBy("EMERGENCY_SOS");
          ride.setCancelledAt(LocalDateTime.now());
          rideRepository.save(ride);
        }
      });
    }

    // Notify user
    notificationService.sendNotification(userId, "🚨 SOS Activated",
        "Emergency alert sent. Help is on the way.", "SOS");

    // Broadcast to admin dashboard
    Map<String, Object> alertData = new HashMap<>();
    alertData.put("alertId", alert.getId());
    alertData.put("userId", userId);
    alertData.put("userName", user.getFullName());
    alertData.put("userPhone", user.getPhone());
    alertData.put("alertType", alertType);
    alertData.put("latitude", latitude);
    alertData.put("longitude", longitude);
    alertData.put("rideId", rideId);
    alertData.put("timestamp", System.currentTimeMillis());
    messagingTemplate.convertAndSend("/topic/admin/emergency-alerts", alertData);

    log.error("🚨 EMERGENCY SOS - User: {}, Phone: {}, Location: ({},{})",
        user.getFullName(), user.getPhone(), latitude, longitude);

    return alert;
  }

  @Transactional
  public EmergencyAlert acknowledgeAlert(UUID alertId) {
    EmergencyAlert alert = alertRepository.findById(alertId)
        .orElseThrow(() -> new ResourceNotFoundException("Alert not found"));
    alert.setStatus("ACKNOWLEDGED");
    return alertRepository.save(alert);
  }

  @Transactional
  public EmergencyAlert resolveAlert(UUID alertId) {
    EmergencyAlert alert = alertRepository.findById(alertId)
        .orElseThrow(() -> new ResourceNotFoundException("Alert not found"));
    alert.setStatus("RESOLVED");
    alert.setResolvedAt(LocalDateTime.now());
    return alertRepository.save(alert);
  }

  @Transactional
  public EmergencyContact addContact(UUID userId, String name, String phone, String relation) {
    return contactRepository.save(EmergencyContact.builder()
        .userId(userId)
        .contactName(name)
        .contactPhone(phone)
        .relation(relation)
        .isDefault(false)
        .build());
  }

  public List<EmergencyContact> getContacts(UUID userId) {
    return contactRepository.findByUserId(userId);
  }

  @Transactional
  public void deleteContact(UUID userId, UUID contactId) {
    EmergencyContact contact = contactRepository.findById(contactId)
        .orElseThrow(() -> new ResourceNotFoundException("Contact not found"));
    if (!contact.getUserId().equals(userId)) {
      throw new RuntimeException("Unauthorized");
    }
    contactRepository.delete(contact);
  }

  public List<EmergencyAlert> getOpenAlerts() {
    return alertRepository.findByStatusOrderByCreatedAtDesc("OPEN");
  }

  public List<EmergencyAlert> getAllAlerts() {
    return alertRepository.findAll();
  }
}
