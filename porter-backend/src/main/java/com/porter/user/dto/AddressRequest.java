package com.porter.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AddressRequest {
  @NotBlank
  private String label;
  @NotBlank
  private String addressLine;
  @NotNull
  private Double latitude;
  @NotNull
  private Double longitude;
}
