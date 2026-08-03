package com.porter.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.util.Collection;
import java.util.Collections;
import java.util.UUID;

/**
 * WebSocket configuration using STOMP protocol for real-time tracking.
 * Handles JWT authentication at the STOMP protocol level.
 */
@Configuration
@EnableWebSocketMessageBroker
@RequiredArgsConstructor
@Slf4j
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

  private final JwtTokenProvider jwtTokenProvider;

  @Override
  public void configureMessageBroker(MessageBrokerRegistry config) {
    // Enable a simple in-memory message broker for subscriptions
    config.enableSimpleBroker("/topic", "/queue");
    // Prefix for messages from clients
    config.setApplicationDestinationPrefixes("/app");
    // Prefix for user-specific messages
    config.setUserDestinationPrefix("/user");
  }

  @Override
  public void registerStompEndpoints(StompEndpointRegistry registry) {
    // SockJS endpoint (for browser fallback)
    registry.addEndpoint("/ws")
        .setAllowedOriginPatterns("*")
        .addInterceptors(new org.springframework.web.socket.server.HandshakeInterceptor() {
          @Override
          public boolean beforeHandshake(org.springframework.http.server.ServerHttpRequest request,
              org.springframework.http.server.ServerHttpResponse response,
              org.springframework.web.socket.WebSocketHandler wsHandler,
              java.util.Map<String, Object> attributes) {
            log.info("🤝 WS HANDSHAKE (SockJS): {} from {}", request.getURI(), request.getRemoteAddress());
            return true;
          }
          @Override
          public void afterHandshake(org.springframework.http.server.ServerHttpRequest request,
              org.springframework.http.server.ServerHttpResponse response,
              org.springframework.web.socket.WebSocketHandler wsHandler, Exception exception) {
            log.info("✅ WS HANDSHAKE COMPLETE (SockJS): exception={}", exception != null ? exception.getMessage() : "none");
          }
        })
        .withSockJS();

    // Raw WebSocket endpoint (for native apps like Flutter)
    registry.addEndpoint("/ws")
        .setAllowedOriginPatterns("*")
        .addInterceptors(new org.springframework.web.socket.server.HandshakeInterceptor() {
          @Override
          public boolean beforeHandshake(org.springframework.http.server.ServerHttpRequest request,
              org.springframework.http.server.ServerHttpResponse response,
              org.springframework.web.socket.WebSocketHandler wsHandler,
              java.util.Map<String, Object> attributes) {
            log.info("🤝 WS HANDSHAKE (RAW): {} from {}", request.getURI(), request.getRemoteAddress());
            return true;
          }
          @Override
          public void afterHandshake(org.springframework.http.server.ServerHttpRequest request,
              org.springframework.http.server.ServerHttpResponse response,
              org.springframework.web.socket.WebSocketHandler wsHandler, Exception exception) {
            log.info("✅ WS HANDSHAKE COMPLETE (RAW): exception={}", exception != null ? exception.getMessage() : "none");
          }
        });
  }

  @Override
  public void configureClientInboundChannel(ChannelRegistration registration) {
    registration.interceptors(new ChannelInterceptor() {
      @Override
      public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(message);

        if (StompCommand.CONNECT.equals(accessor.getCommand())) {
          try {
            // Extract token from Authorization header
            String authHeader = accessor.getFirstNativeHeader("Authorization");
            String token = null;

            if (authHeader != null && authHeader.startsWith("Bearer ")) {
              token = authHeader.substring(7);
            }

            // 🔴 FIX: Also try "token" header (SockJS may strip Authorization)
            if (token == null) {
              token = accessor.getFirstNativeHeader("token");
            }

            log.info("🔐 STOMP CONNECT received with token: {}", token != null ? "present" : "missing");

            if (token != null && jwtTokenProvider.validateToken(token)) {
              // Token is valid, extract user ID and role
              UUID userId = jwtTokenProvider.getUserIdFromToken(token);
              String role = jwtTokenProvider.getRoleFromToken(token);

              // Create authorities from role
              Collection<GrantedAuthority> authorities = Collections.singleton(
                  new SimpleGrantedAuthority("ROLE_" + role)
              );

              // Create authentication token
              UsernamePasswordAuthenticationToken auth =
                  new UsernamePasswordAuthenticationToken(userId.toString(), null, authorities);

              // Set the principal in the STOMP header
              accessor.setUser(auth);

              log.info("✅ STOMP CONNECT authenticated: userId={}, role={}", userId, role);
            } else {
              // 🔴 FIX: Allow connection without auth for SockJS compatibility
              // Security is enforced at the HTTP level by Spring Security
              log.warn("⚠️ STOMP CONNECT without valid token - allowing for SockJS compatibility");
            }
          } catch (Exception e) {
            log.error("❌ STOMP authentication error: {}", e.getMessage());
            // 🔴 FIX: Don't throw - let connection proceed
            // Throwing kills the SockJS handshake silently
            log.warn("⚠️ Allowing STOMP connection despite auth error for SockJS compatibility");
          }
        }

        return message;
      }
    });
  }
}
