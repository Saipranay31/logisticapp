package com.porter.user.service;

import com.porter.auth.entity.User;
import com.porter.auth.repository.UserRepository;
import com.porter.common.exception.ResourceNotFoundException;
import com.porter.user.dto.AddressRequest;
import com.porter.user.dto.UserProfileDto;
import com.porter.user.entity.UserAddress;
import com.porter.user.entity.UserProfile;
import com.porter.user.repository.UserAddressRepository;
import com.porter.user.repository.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

  private final UserRepository userRepository;
  private final UserProfileRepository userProfileRepository;
  private final UserAddressRepository userAddressRepository;

  public UserProfileDto getProfile(UUID userId) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("User not found"));

    UserProfile profile = userProfileRepository.findByUserId(userId)
        .orElse(null);

    return UserProfileDto.builder()
        .userId(user.getId())
        .fullName(user.getFullName())
        .phone(user.getPhone())
        .avatarUrl(profile != null ? profile.getAvatarUrl() : null)
        .build();
  }

  @Transactional
  public UserProfileDto updateProfile(UUID userId, String fullName, String avatarUrl) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("User not found"));

    log.info("📝 UPDATE PROFILE REQUEST: userId={}, fullName={}, avatarUrl={}", userId, fullName, avatarUrl);

    if (fullName != null && !fullName.isBlank()) {
      log.info("✅ UPDATING FULL NAME: {} → {}", user.getFullName(), fullName);
      user.setFullName(fullName);
    }
    userRepository.save(user);

    UserProfile profile = userProfileRepository.findByUserId(userId)
        .orElseGet(() -> {
          UserProfile p = new UserProfile();
          p.setUserId(userId);
          return p;
        });

    if (avatarUrl != null)
      profile.setAvatarUrl(avatarUrl);
    userProfileRepository.save(profile);

    log.info("✅ PROFILE SAVED: userId={}, fullName={}, avatarUrl={}", userId, user.getFullName(), profile.getAvatarUrl());

    return getProfile(userId);
  }

  public List<UserAddress> getAddresses(UUID userId) {
    return userAddressRepository.findByUserId(userId);
  }

  @Transactional
  public UserAddress addAddress(UUID userId, AddressRequest request) {
    UserAddress address = UserAddress.builder()
        .userId(userId)
        .label(request.getLabel())
        .addressLine(request.getAddressLine())
        .latitude(request.getLatitude())
        .longitude(request.getLongitude())
        .build();
    return userAddressRepository.save(address);
  }

  @Transactional
  public void deleteAddress(UUID userId, UUID addressId) {
    UserAddress address = userAddressRepository.findById(addressId)
        .orElseThrow(() -> new ResourceNotFoundException("Address not found"));
    if (!address.getUserId().equals(userId)) {
      throw new ResourceNotFoundException("Address not found");
    }
    userAddressRepository.delete(address);
  }
}
