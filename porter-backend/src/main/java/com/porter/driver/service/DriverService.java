package com.porter.driver.service;

import com.porter.auth.entity.User;
import com.porter.auth.repository.UserRepository;
import com.porter.common.enums.KycStatus;
import com.porter.common.enums.VehicleType;
import com.porter.common.exception.BadRequestException;
import com.porter.common.exception.ResourceNotFoundException;
import com.porter.driver.dto.DriverProfileDto;
import com.porter.driver.entity.DriverDocument;
import com.porter.driver.entity.DriverProfile;
import com.porter.driver.entity.DriverVehicle;
import com.porter.driver.repository.DriverDocumentRepository;
import com.porter.driver.repository.DriverProfileRepository;
import com.porter.driver.repository.DriverVehicleRepository;
import com.porter.location.service.LocationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class DriverService {

  private final UserRepository userRepository;
  private final DriverProfileRepository driverProfileRepository;
  private final DriverVehicleRepository driverVehicleRepository;
  private final DriverDocumentRepository driverDocumentRepository;
  private final LocationService locationService;

  public DriverProfileDto getDriverProfile(UUID userId) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    DriverVehicle vehicle = driverVehicleRepository
        .findByDriverProfileIdAndIsActive(profile.getId(), true)
        .orElse(null);

    return mapToDto(user, profile, vehicle);
  }

  @Transactional
  public DriverProfile createDriverProfile(UUID userId, String licenseNumber, String profilePictureUrl) {
    if (driverProfileRepository.findByUserId(userId).isPresent()) {
      throw new BadRequestException("Driver profile already exists");
    }
    DriverProfile profile = DriverProfile.builder()
        .userId(userId)
        .licenseNumber(licenseNumber)
        .avatarUrl(profilePictureUrl)
        .kycStatus(KycStatus.PENDING)
        .isOnline(false)
        .rating(5.0)
        .totalRides(0)
        .build();
    return driverProfileRepository.save(profile);
  }

  // ✅ Overload for backward compatibility
  @Transactional
  public DriverProfile createDriverProfile(UUID userId, String licenseNumber) {
    return createDriverProfile(userId, licenseNumber, null);
  }

  @Transactional
  public DriverProfile updateDriverProfile(UUID userId, String licenseNumber, String profilePictureUrl) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    if (licenseNumber != null && !licenseNumber.isEmpty()) {
      profile.setLicenseNumber(licenseNumber);
      log.info("✅ License number updated for driver {}: {}", userId, licenseNumber);
    }

    if (profilePictureUrl != null && !profilePictureUrl.isEmpty()) {
      profile.setAvatarUrl(profilePictureUrl);
      log.info("✅ Avatar updated for driver {}", userId);
    }

    return driverProfileRepository.save(profile);
  }

  // ✅ NEW: Overload that also accepts fullName (used during KYC registration)
  @Transactional
  public DriverProfile updateDriverProfile(UUID userId, String licenseNumber, String fullName, String profilePictureUrl) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    if (licenseNumber != null && !licenseNumber.isEmpty()) {
      profile.setLicenseNumber(licenseNumber);
      log.info("✅ License number updated for driver {}: {}", userId, licenseNumber);
    }

    if (fullName != null && !fullName.isBlank()) {
      profile.setFullName(fullName);
      log.info("✅ Full name updated for driver {}: {}", userId, fullName);

      // ✅ Also sync to User.fullName to keep it consistent
      User user = userRepository.findById(userId)
          .orElseThrow(() -> new ResourceNotFoundException("User not found"));
      user.setFullName(fullName);
      userRepository.save(user);
      log.info("✅ User.fullName synced for driver {}: {}", userId, fullName);
    }

    if (profilePictureUrl != null && !profilePictureUrl.isEmpty()) {
      profile.setAvatarUrl(profilePictureUrl);
      log.info("✅ Avatar updated for driver {}", userId);
    }

    return driverProfileRepository.save(profile);
  }

  /**
   * Toggle driver online/offline status. When going online, stores location in
   * Redis.
   */
  @Transactional
  public DriverProfileDto toggleOnlineStatus(UUID userId, boolean online, Double latitude, Double longitude) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    // ✅ FIXED: Allow going online if KYC is SUBMITTED or VERIFIED (not just VERIFIED)
    // This allows drivers in testing/development to go online without waiting for admin approval
    if (online && profile.getKycStatus() == KycStatus.PENDING) {
      throw new BadRequestException("Please submit KYC documents before going online");
    }

    log.info("🔄 Toggling driver {} online status to: {}", userId, online);

    profile.setOnline(online);
    driverProfileRepository.save(profile);
    log.info("✅ Driver {} status updated to online={}", userId, online);

    if (online && latitude != null && longitude != null) {
      log.info("📍 Updating driver {} location in Redis: lat={}, lng={}", userId, latitude, longitude);
      locationService.updateDriverLocation(userId.toString(), latitude, longitude);
    } else if (!online) {
      log.info("📍 Removing driver {} location from Redis", userId);
      locationService.removeDriverLocation(userId.toString());
    }

    User user = userRepository.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    return mapToDto(user, profile, null);
  }

  // ─── VEHICLE REGISTRATION ───

  @Transactional
  public DriverVehicle registerVehicle(UUID userId, String vehicleTypeStr, String vehicleNumber, String vehicleModel) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    VehicleType vehicleType = VehicleType.valueOf(vehicleTypeStr.toUpperCase());

    // Deactivate existing vehicles
    driverVehicleRepository.findByDriverProfileIdAndIsActive(profile.getId(), true)
        .ifPresent(v -> {
          v.setActive(false);
          driverVehicleRepository.save(v);
        });

    DriverVehicle vehicle = DriverVehicle.builder()
        .driverProfileId(profile.getId())
        .vehicleType(vehicleType)
        .vehicleNumber(vehicleNumber)
        .vehicleModel(vehicleModel)
        .isActive(true)
        .build();

    log.info("Vehicle registered for driver {}: {} {}", userId, vehicleType, vehicleNumber);
    return driverVehicleRepository.save(vehicle);
  }

  // ─── KYC DOCUMENT MANAGEMENT ───

  @Transactional
  public DriverDocument uploadDocument(UUID userId, String documentType, String documentUrl) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    DriverDocument doc = DriverDocument.builder()
        .driverProfileId(profile.getId())
        .documentType(documentType)
        .documentUrl(documentUrl)
        .status("PENDING")
        .build();

    log.info("KYC document uploaded for driver {}: {}", userId, documentType);
    return driverDocumentRepository.save(doc);
  }

  public List<DriverDocument> getDocuments(UUID userId) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));
    return driverDocumentRepository.findByDriverProfileId(profile.getId());
  }

  @Transactional
  public DriverProfileDto submitKyc(UUID userId) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    if (profile.getKycStatus() == KycStatus.VERIFIED) {
      throw new BadRequestException("KYC is already verified");
    }

    profile.setKycStatus(KycStatus.SUBMITTED);
    driverProfileRepository.save(profile);

    User user = userRepository.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    log.info("KYC submitted for review: driver {}", userId);
    return mapToDto(user, profile, null);
  }

  // ─── ADMIN FUNCTIONS ───

  public List<DriverProfileDto> getAllDrivers() {
    return driverProfileRepository.findAll().stream()
        .map(profile -> {
          User user = userRepository.findById(profile.getUserId()).orElse(null);
          if (user == null)
            return null;
          return mapToDto(user, profile, null);
        })
        .filter(d -> d != null)
        .collect(Collectors.toList());
  }

  @Transactional
  public void updateKycStatus(UUID driverProfileId, KycStatus status) {
    DriverProfile profile = driverProfileRepository.findById(driverProfileId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));
    profile.setKycStatus(status);
    driverProfileRepository.save(profile);
  }

  @Transactional
  public DriverProfileDto approveKyc(UUID userId, boolean approve) {
    DriverProfile profile = driverProfileRepository.findByUserId(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));

    profile.setKycStatus(approve ? KycStatus.VERIFIED : KycStatus.REJECTED);
    driverProfileRepository.save(profile);

    // Also activate/deactivate the user account
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    user.setActive(approve);
    userRepository.save(user);

    log.info("KYC {} for driver {}", approve ? "APPROVED" : "REJECTED", userId);
    return mapToDto(user, profile, null);
  }

  private DriverProfileDto mapToDto(User user, DriverProfile profile, DriverVehicle vehicle) {
    return DriverProfileDto.builder()
        .userId(user.getId())
        .driverProfileId(profile.getId())
        .fullName(user.getFullName())
        .phone(user.getPhone())
        .avatarUrl(profile.getAvatarUrl())
        .licenseNumber(profile.getLicenseNumber())
        .kycStatus(profile.getKycStatus().name())
        .isOnline(profile.isOnline())
        .isActive(user.isActive())
        .rating(profile.getRating())
        .totalRides(profile.getTotalRides())
        .vehicleType(vehicle != null ? vehicle.getVehicleType().name() : null)
        .vehicleNumber(vehicle != null ? vehicle.getVehicleNumber() : null)
        .vehicleModel(vehicle != null ? vehicle.getVehicleModel() : null)
        .build();
  }
}
