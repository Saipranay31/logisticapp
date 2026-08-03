package com.porter.ride.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "ride_location_updates", indexes = {
    @Index(name = "idx_ride_loc_ride", columnList = "ride_id"),
    @Index(name = "idx_ride_loc_time", columnList = "ride_id, recorded_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RideLocationUpdate extends BaseEntity {

  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(name = "driver_id", nullable = false)
  private UUID driverId;

  @Column(nullable = false)
  private Double latitude;

  @Column(nullable = false)
  private Double longitude;

  private Double speed; // km/h
  private Double heading; // 0-360 degrees
  private Double accuracy; // meters
  private Double altitude; // meters

  @Column(name = "recorded_at", nullable = false)
  private LocalDateTime recordedAt;
}
