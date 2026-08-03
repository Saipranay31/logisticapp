package com.porter.ride.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "chat_messages")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChatMessage extends BaseEntity {

  @Column(name = "ride_id", nullable = false)
  private UUID rideId;

  @Column(name = "sender_id", nullable = false)
  private UUID senderId;

  @Column(name = "sender_role", nullable = false)
  private String senderRole; // USER or DRIVER

  @Column(nullable = false, length = 1000)
  private String message;
}
