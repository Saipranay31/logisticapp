package com.porter.config;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;
import java.time.Duration;

/**
 * HTTP Client configuration for making external API calls
 */
@Configuration
public class HttpClientConfig {

  /**
   * RestTemplate bean for making HTTP requests
   * Configured with timeout and other settings
   */
  @Bean
  public RestTemplate restTemplate(RestTemplateBuilder builder) {
    return builder
        .setConnectTimeout(Duration.ofSeconds(10))
        .setReadTimeout(Duration.ofSeconds(30))
        .build();
  }
}
