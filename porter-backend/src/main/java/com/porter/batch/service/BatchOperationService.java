package com.porter.batch.service;

import com.porter.common.enums.KycStatus;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.notification.service.NotificationService;
import com.porter.auth.repository.UserRepository;
import com.porter.auth.entity.User;
import com.porter.common.enums.Role;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * Batch operations for admin: bulk KYC approval, bulk notifications, data
 * export.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BatchOperationService {

  private final DriverProfileRepository driverProfileRepository;
  private final NotificationService notificationService;
  private final UserRepository userRepository;

  /**
   * Batch approve KYC for multiple drivers.
   */
  @Transactional
  public Map<String, Object> batchApproveKyc(List<UUID> driverIds) {
    int approved = 0;
    int failed = 0;
    List<String> errors = new ArrayList<>();

    for (UUID driverId : driverIds) {
      try {
        DriverProfile driver = driverProfileRepository.findByUserId(driverId)
            .orElseThrow(() -> new RuntimeException("Driver not found: " + driverId));
        driver.setKycStatus(KycStatus.VERIFIED);
        driverProfileRepository.save(driver);
        approved++;

        notificationService.sendNotification(driverId,
            "KYC Approved", "Your documents have been verified. You can now accept rides!",
            "KYC_APPROVED");

        log.info("KYC approved for driver {}", driverId);
      } catch (Exception e) {
        failed++;
        errors.add(driverId + ": " + e.getMessage());
        log.error("Failed to approve KYC for driver {}: {}", driverId, e.getMessage());
      }
    }

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("approved", approved);
    result.put("failed", failed);
    result.put("total", driverIds.size());
    if (!errors.isEmpty())
      result.put("errors", errors);
    return result;
  }

  /**
   * Send notification to a target audience.
   */
  public Map<String, Object> batchSendNotification(String targetAudience, String title, String message) {
    List<User> targets;

    switch (targetAudience) {
      case "all_users" -> targets = userRepository.findByRole(Role.USER);
      case "all_drivers" -> targets = userRepository.findByRole(Role.DRIVER);
      default -> targets = userRepository.findAll();
    }

    int sent = 0;
    int failed = 0;

    for (User user : targets) {
      try {
        notificationService.sendNotification(user.getId(), title, message, "ADMIN_BROADCAST");
        sent++;
      } catch (Exception e) {
        failed++;
      }
    }

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("sent", sent);
    result.put("failed", failed);
    result.put("total", targets.size());
    return result;
  }

  /**
   * Export data as JSON (CSV export would require writing to file system).
   */
  public Map<String, Object> exportData(String dataType, String startDate, String endDate) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("dataType", dataType);
    result.put("startDate", startDate);
    result.put("endDate", endDate);
    result.put("format", "JSON");

    switch (dataType) {
      case "drivers" -> {
        List<DriverProfile> drivers = driverProfileRepository.findAll();
        result.put("count", drivers.size());
        result.put("data", drivers);
      }
      case "users" -> {
        List<User> users = userRepository.findByRole(Role.USER);
        result.put("count", users.size());
        result.put("data", users);
      }
      default -> {
        result.put("count", 0);
        result.put("message", "Unsupported data type: " + dataType);
      }
    }

    return result;
  }
}
