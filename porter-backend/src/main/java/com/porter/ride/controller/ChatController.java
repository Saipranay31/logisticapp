package com.porter.ride.controller;

import com.porter.common.dto.ApiResponse;
import com.porter.ride.entity.ChatMessage;
import com.porter.ride.service.ChatService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/rides")
@RequiredArgsConstructor
public class ChatController {

  private final ChatService chatService;

  @PostMapping("/{rideId}/chat")
  public ResponseEntity<ApiResponse<Map<String, Object>>> sendMessage(
      Authentication auth, @PathVariable UUID rideId,
      @RequestBody Map<String, String> body) {
    UUID senderId = UUID.fromString(auth.getName());
    String senderRole = body.getOrDefault("senderRole", "USER");
    String message = body.get("message");

    ChatMessage msg = chatService.sendMessage(rideId, senderId, senderRole, message);

    Map<String, Object> response = Map.of(
        "id", msg.getId(),
        "rideId", msg.getRideId(),
        "senderId", msg.getSenderId(),
        "senderRole", msg.getSenderRole(),
        "message", msg.getMessage(),
        "timestamp", msg.getCreatedAt()
    );

    return ResponseEntity.ok(ApiResponse.success(response));
  }

  @GetMapping("/{rideId}/chat")
  public ResponseEntity<ApiResponse<List<ChatMessage>>> getMessages(
      @PathVariable UUID rideId) {
    return ResponseEntity.ok(ApiResponse.success(chatService.getMessages(rideId)));
  }
}
