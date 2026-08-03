package com.porter.driver.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DriverProfileDto {
  private UUID userId;
  private UUID driverProfileId;
  private String fullName;
  private String phone;
  private String avatarUrl;
  private String licenseNumber;
  private String kycStatus;
  @JsonProperty("isOnline")
  private boolean isOnline;
  @JsonProperty("isActive")
  private boolean isActive;
  private double rating;
  private int totalRides;
  private String vehicleType;
  private String vehicleNumber;
  private String vehicleModel;
}
