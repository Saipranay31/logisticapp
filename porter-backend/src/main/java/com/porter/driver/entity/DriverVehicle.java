package com.porter.driver.entity;

import com.porter.common.entity.BaseEntity;
import com.porter.common.enums.VehicleType;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "driver_vehicles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DriverVehicle extends BaseEntity {

  @Column(name = "driver_profile_id", nullable = false)
  private UUID driverProfileId;

  @Enumerated(EnumType.STRING)
  @Column(name = "vehicle_type", nullable = false)
  private VehicleType vehicleType;

  @Column(name = "vehicle_number", nullable = false)
  private String vehicleNumber;

  @Column(name = "vehicle_model")
  private String vehicleModel;

  @Column(name = "is_active", nullable = false)
  private boolean isActive = true;
}
