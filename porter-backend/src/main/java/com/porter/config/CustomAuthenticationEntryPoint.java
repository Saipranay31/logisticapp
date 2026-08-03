package com.porter.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.porter.common.dto.ApiResponse;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * Custom authentication entry point that returns JSON error responses
 * instead of empty 403 responses when authentication fails.
 */
@Component
@Slf4j
public class CustomAuthenticationEntryPoint implements AuthenticationEntryPoint {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Override
  public void commence(HttpServletRequest request,
                       HttpServletResponse response,
                       AuthenticationException authException) throws IOException, ServletException {

    log.warn("❌ Authentication failed for request: {} - {}", request.getRequestURI(), authException.getMessage());

    // ✅ FIX: Return proper JSON error response instead of empty 403
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);

    ApiResponse<Void> errorResponse = ApiResponse.error("Unauthorized: " + authException.getMessage());
    response.getWriter().write(objectMapper.writeValueAsString(errorResponse));
  }
}
