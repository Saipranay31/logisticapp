package com.porter.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DashboardDto {
  private long totalUsers;
  private long totalDrivers;
  private long activeDrivers;
  private long totalRides;
  private long activeRides;
  private long completedRides;
  private double totalRevenue;
  private double todayRevenue;
  private long todayRides;
}
