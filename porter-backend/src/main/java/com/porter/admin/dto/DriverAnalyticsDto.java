package com.porter.admin.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DriverAnalyticsDto {
  private UUID userId;
  private String fullName;
  private String phone;
  private String avatarUrl;
  private double rating;
  private long totalRides;
  private String kycStatus;
  @JsonProperty("isOnline")
  private boolean isOnline;
  @JsonProperty("isActive")
  private boolean isActive;
  private String licenseNumber;

  // Today stats
  private long todayRides;
  private double todayEarnings;

  // This week stats
  private long weekRides;
  private double weekEarnings;

  // This month stats
  private long monthRides;
  private double monthEarnings;

  // All-time earnings
  private double totalEarnings;

  // Rating breakdown
  private long totalRatings;
  private Map<String, Long> ratingDistribution;
}
