package com.porter.ride.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CreateRideRequest {
  @NotBlank
  private String vehicleType;
  @NotBlank
  private String pickupAddress;
  @NotNull
  private Double pickupLatitude;
  @NotNull
  private Double pickupLongitude;
  @NotBlank
  private String dropAddress;
  @NotNull
  private Double dropLatitude;
  @NotNull
  private Double dropLongitude;
}
