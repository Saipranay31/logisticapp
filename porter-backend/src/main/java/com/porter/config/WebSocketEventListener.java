package com.porter.config;

import com.porter.payment.service.FareCalculationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionSubscribeEvent;
import org.springframework.web.socket.messaging.SessionUnsubscribeEvent;

/**
 * Tracks WebSocket subscriptions/unsubscriptions to optimize fare broadcasts
 * Only broadcasts fare updates when clients are actively subscribed
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class WebSocketEventListener {

  private final FareCalculationService fareCalculationService;

  /**
   * Track when a user/driver subscribes to a ride fare topic
   * Topics look like: /topic/ride/{rideId}/fare
   */
  @EventListener
  public void handleSubscribe(SessionSubscribeEvent event) {
    String destination = event.getMessage().getHeaders().get("simpDestination", String.class);

    if (destination != null && destination.contains("/topic/ride/") && destination.contains("/fare")) {
      // Extract rideId from destination: /topic/ride/{rideId}/fare
      String rideId = destination.split("/")[3];
      fareCalculationService.addSubscriber(rideId);
      log.debug("🟢 WebSocket SUBSCRIBE: destination={}, rideId={}", destination, rideId);
    }
  }

  /**
   * Track when a user/driver unsubscribes from a ride fare topic
   */
  @EventListener
  public void handleUnsubscribe(SessionUnsubscribeEvent event) {
    String header = event.getMessage().getHeaders().get("simpDestination", String.class);

    if (header != null && header.contains("/topic/ride/") && header.contains("/fare")) {
      // Extract rideId
      String rideId = header.split("/")[3];
      fareCalculationService.removeSubscriber(rideId);
      log.debug("🔴 WebSocket UNSUBSCRIBE: destination={}, rideId={}", header, rideId);
    }
  }
}
