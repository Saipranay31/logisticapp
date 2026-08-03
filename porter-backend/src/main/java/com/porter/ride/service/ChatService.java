package com.porter.ride.service;

import com.porter.ride.entity.ChatMessage;
import com.porter.ride.repository.ChatMessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChatService {

  private final ChatMessageRepository chatMessageRepository;
  private final SimpMessagingTemplate messagingTemplate;

  public ChatMessage sendMessage(UUID rideId, UUID senderId, String senderRole, String message) {
    ChatMessage chatMessage = ChatMessage.builder()
        .rideId(rideId)
        .senderId(senderId)
        .senderRole(senderRole)
        .message(message)
        .build();

    chatMessage = chatMessageRepository.save(chatMessage);

    // Broadcast via WebSocket to ride chat topic
    Map<String, Object> payload = new HashMap<>();
    payload.put("id", chatMessage.getId());
    payload.put("rideId", rideId);
    payload.put("senderId", senderId);
    payload.put("senderRole", senderRole);
    payload.put("message", message);
    payload.put("timestamp", chatMessage.getCreatedAt());

    messagingTemplate.convertAndSend("/topic/ride/" + rideId + "/chat", payload);

    log.info("💬 Chat message sent for ride {} by {} ({})", rideId, senderId, senderRole);
    return chatMessage;
  }

  public List<ChatMessage> getMessages(UUID rideId) {
    return chatMessageRepository.findByRideIdOrderByCreatedAtAsc(rideId);
  }
}
