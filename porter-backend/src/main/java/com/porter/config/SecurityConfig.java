package com.porter.config;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Spring Security configuration with JWT-based stateless authentication.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

  private final JwtAuthenticationFilter jwtAuthenticationFilter;
  private final CustomAuthenticationEntryPoint authenticationEntryPoint;

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(AbstractHttpConfigurer::disable)
        .cors(cors -> cors.configurationSource(corsConfigurationSource()))
        .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        // ✅ FIX: Add custom authentication entry point to return JSON errors
        .exceptionHandling(exception -> exception.authenticationEntryPoint(authenticationEntryPoint))
        .authorizeHttpRequests(auth -> auth
            // Public endpoints
            .requestMatchers("/api/auth/**").permitAll()
            .requestMatchers("/api/files/**").permitAll()  // ✅ ALL FILES PUBLIC - Profile images, documents, etc
            .requestMatchers("/api/files/drivers/**").permitAll()  // ✅ Driver profile images public
            .requestMatchers("/ws/**").permitAll()
            .requestMatchers("/error").permitAll()  // ✅ Spring Boot error endpoint must be public
            .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
            // Swagger / OpenAPI
            .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()

            // Admin endpoints
            .requestMatchers("/api/admin/**").hasRole("ADMIN")

            // Driver endpoints
            .requestMatchers("/api/driver/**").hasAnyRole("DRIVER", "ADMIN")

            // User endpoints
            .requestMatchers("/api/user/**").hasAnyRole("USER", "ADMIN")

            // Ride endpoints accessible by USER and DRIVER
            .requestMatchers("/api/rides/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Location endpoints (driver sends location, user tracks driver)
            .requestMatchers("/api/location/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Notification endpoints
            .requestMatchers("/api/notifications/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Financial endpoints
            .requestMatchers("/api/financial/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Payment endpoints
            .requestMatchers("/api/payments/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Emergency endpoints
            .requestMatchers("/api/emergency/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Support ticket endpoints
            .requestMatchers("/api/support/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Notification preference endpoints
            .requestMatchers("/api/notification-preferences/**").hasAnyRole("USER", "DRIVER", "ADMIN")

            // Everything else requires authentication
            .anyRequest().authenticated())
        .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

    return http.build();
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }

  @Bean
  public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration configuration = new CorsConfiguration();
    configuration.setAllowedOrigins(List.of("*"));
    configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
    configuration.setAllowedHeaders(List.of("*"));
    configuration.setExposedHeaders(List.of("Authorization"));

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", configuration);
    return source;
  }
}
