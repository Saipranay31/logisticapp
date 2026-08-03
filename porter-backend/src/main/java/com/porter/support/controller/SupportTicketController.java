package com.porter.support.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.support.entity.SupportTicket;
import com.porter.support.entity.TicketMessage;
import com.porter.support.service.SupportTicketService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/support")
@RequiredArgsConstructor
public class SupportTicketController {

  private final SupportTicketService ticketService;

  @PostMapping("/tickets")
  public ResponseEntity<ApiResponse<SupportTicket>> createTicket(
      Authentication auth, @RequestBody Map<String, String> body) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(
        ticketService.createTicket(userId,
            body.get("subject"), body.get("description"),
            body.getOrDefault("category", "TECHNICAL"),
            body.get("rideId"))));
  }

  @GetMapping("/tickets")
  public ResponseEntity<ApiResponse<List<SupportTicket>>> getUserTickets(Authentication auth) {
    UUID userId = UUID.fromString(auth.getName());
    return ResponseEntity.ok(ApiResponse.success(ticketService.getUserTickets(userId)));
  }

  @PostMapping("/tickets/{ticketId}/messages")
  public ResponseEntity<ApiResponse<TicketMessage>> addMessage(
      Authentication auth, @PathVariable UUID ticketId,
      @RequestBody Map<String, Object> body) {
    UUID userId = UUID.fromString(auth.getName());
    @SuppressWarnings("unchecked")
    List<String> attachments = body.containsKey("attachments")
        ? (List<String>) body.get("attachments")
        : null;

    return ResponseEntity.ok(ApiResponse.success(
        ticketService.addMessage(ticketId, userId,
            (String) body.get("message"), "USER", attachments)));
  }

  @GetMapping("/tickets/{ticketId}/messages")
  public ResponseEntity<ApiResponse<List<TicketMessage>>> getMessages(@PathVariable UUID ticketId) {
    return ResponseEntity.ok(ApiResponse.success(ticketService.getTicketMessages(ticketId)));
  }
}
