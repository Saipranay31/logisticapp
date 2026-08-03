package com.porter.ride.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FareConfigDto {
  private double baseFare;
  private double perKmRate;
  private double perMinRate;
  private Map<String, Double> vehicleMultipliers;
  private String currency;
  private String updatedAt;
}
