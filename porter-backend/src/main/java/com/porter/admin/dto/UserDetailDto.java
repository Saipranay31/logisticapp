package com.porter.admin.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserDetailDto {
  private UUID userId;
  private String fullName;
  private String phone;
  private String email;
  private String avatarUrl;
  @JsonProperty("isActive")
  private boolean isActive;
  private LocalDateTime joinedAt;

  // Ride stats
  private long totalRides;
  private long todayRides;
  private long weekRides;
  private long monthRides;
  private double totalSpent;
  private double todaySpent;
  private double weekSpent;
  private double monthSpent;

  // Rating stats (rated by drivers)
  private double averageRating;
  private long totalRatings;
  private Map<String, Long> ratingDistribution;
}
