package com.porter.support.service;

import com.porter.common.exception.ResourceNotFoundException;
import com.porter.support.entity.SupportTicket;
import com.porter.support.entity.TicketMessage;
import com.porter.support.repository.SupportTicketRepository;
import com.porter.support.repository.TicketMessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SupportTicketService {

  private final SupportTicketRepository ticketRepository;
  private final TicketMessageRepository messageRepository;

  @Transactional
  public SupportTicket createTicket(UUID userId, String subject, String description,
      String category, String rideId) {
    String ticketNumber = "TICKET-" + System.currentTimeMillis();

    SupportTicket ticket = SupportTicket.builder()
        .ticketNumber(ticketNumber)
        .userId(userId)
        .rideId(rideId != null && !rideId.isEmpty() ? UUID.fromString(rideId) : null)
        .subject(subject)
        .description(description)
        .category(category != null ? category : "TECHNICAL")
        .priority("MEDIUM")
        .status("OPEN")
        .build();

    ticket = ticketRepository.save(ticket);
    log.info("Support ticket {} created by user {}", ticketNumber, userId);
    return ticket;
  }

  @Transactional
  public TicketMessage addMessage(UUID ticketId, UUID senderId, String message,
      String senderType, List<String> attachmentUrls) {
    SupportTicket ticket = ticketRepository.findById(ticketId)
        .orElseThrow(() -> new ResourceNotFoundException("Ticket not found"));

    // Admin reply moves ticket to IN_PROGRESS
    if ("ADMIN".equals(senderType) && "OPEN".equals(ticket.getStatus())) {
      ticket.setStatus("IN_PROGRESS");
      ticketRepository.save(ticket);
    }

    TicketMessage msg = TicketMessage.builder()
        .ticketId(ticketId)
        .senderId(senderId)
        .senderType(senderType)
        .message(message)
        .attachmentsUrl(attachmentUrls != null ? String.join(",", attachmentUrls) : null)
        .build();

    return messageRepository.save(msg);
  }

  public List<TicketMessage> getTicketMessages(UUID ticketId) {
    return messageRepository.findByTicketIdOrderByCreatedAtAsc(ticketId);
  }

  @Transactional
  public SupportTicket resolveTicket(UUID ticketId) {
    SupportTicket ticket = ticketRepository.findById(ticketId)
        .orElseThrow(() -> new ResourceNotFoundException("Ticket not found"));
    ticket.setStatus("RESOLVED");
    ticket.setResolvedAt(LocalDateTime.now());
    return ticketRepository.save(ticket);
  }

  @Transactional
  public SupportTicket assignTicket(UUID ticketId, UUID adminId) {
    SupportTicket ticket = ticketRepository.findById(ticketId)
        .orElseThrow(() -> new ResourceNotFoundException("Ticket not found"));
    ticket.setAssignedToAdminId(adminId);
    if ("OPEN".equals(ticket.getStatus())) {
      ticket.setStatus("IN_PROGRESS");
    }
    return ticketRepository.save(ticket);
  }

  public List<SupportTicket> getUserTickets(UUID userId) {
    return ticketRepository.findByUserIdOrderByCreatedAtDesc(userId);
  }

  public List<SupportTicket> getOpenTickets() {
    return ticketRepository.findByStatusOrderByCreatedAtAsc("OPEN");
  }

  public List<SupportTicket> getAllTickets() {
    return ticketRepository.findAllByOrderByCreatedAtDesc();
  }
}
