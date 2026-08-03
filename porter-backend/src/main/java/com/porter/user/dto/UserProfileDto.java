package com.porter.user.dto;

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
public class UserProfileDto {
  private UUID userId;
  private String fullName;
  private String phone;
  private String avatarUrl;
  @JsonProperty("isActive")
  private boolean isActive;
}
