package com.porter.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class SendOtpRequest {
  @NotBlank(message = "Phone number is required")
  @Pattern(regexp = "^\\+?[0-9]{10,15}$", message = "Invalid phone number")
  private String phone;

  @NotBlank(message = "Role is required")
  private String role; // USER or DRIVER
}
