package com.porter.driver.dto;

import lombok.Data;
import java.util.UUID;

@Data
public class DriverEarningsDto {
  private UUID driverId;
  private double totalGrossEarnings;
  private double totalCommission;
  private double totalNetEarnings;
  private int totalRides;
}
