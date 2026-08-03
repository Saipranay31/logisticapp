package com.porter.ride.dto;

import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RideRatingDto {
  private UUID id;
  private UUID rideId;
  private Integer rating;
  private String reviewText;
  private LocalDateTime createdAt;
}
