package com.porter.support.entity;

import com.porter.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity
@Table(name = "ticket_messages", indexes = {
    @Index(name = "idx_messages_ticket", columnList = "ticket_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TicketMessage extends BaseEntity {

  @Column(name = "ticket_id", nullable = false)
  private UUID ticketId;

  @Column(name = "sender_id", nullable = false)
  private UUID senderId;

  @Column(name = "sender_type", nullable = false, length = 20)
  private String senderType; // USER, ADMIN

  @Column(nullable = false, columnDefinition = "TEXT")
  private String message;

  @Column(name = "attachments_url", columnDefinition = "TEXT")
  private String attachmentsUrl;
}
