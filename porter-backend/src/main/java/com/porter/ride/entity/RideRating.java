package com.porter.ride.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "ride_ratings",
    uniqueConstraints = @UniqueConstraint(name = "uq_ride_rater", columnNames = {"ride_id", "rater_id"}),
    indexes = {
      @Index(name = "idx_rating_ride", columnList = "ride_id"),
      @Index(name = "idx_rating_ratee", columnList = "ratee_id")
    })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RideRating extends BaseEntity {

  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(name = "rater_id", nullable = false)
  private UUID raterId;

  @Column(name = "ratee_id", nullable = false)
  private UUID rateeId;

  @Column(nullable = false)
  private Integer rating; // 1-5

  @Column(name = "review_text", columnDefinition = "TEXT")
  private String reviewText;
}
