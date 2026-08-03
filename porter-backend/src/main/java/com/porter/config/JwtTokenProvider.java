package com.porter.config;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

/**
 * JWT token provider for generating and validating tokens.
 */
@Component
public class JwtTokenProvider {

  private final SecretKey key;
  private final long expiration;
  private final long refreshExpiration;

  public JwtTokenProvider(
      @Value("${jwt.secret}") String secret,
      @Value("${jwt.expiration}") long expiration,
      @Value("${jwt.refresh-expiration}") long refreshExpiration) {
    this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    this.expiration = expiration;
    this.refreshExpiration = refreshExpiration;
  }

  /**
   * Generate an access token for a given user.
   */
  public String generateToken(UUID userId, String role) {
    Date now = new Date();
    Date expiryDate = new Date(now.getTime() + expiration);

    return Jwts.builder()
        .subject(userId.toString())
        .claim("role", role)
        .issuedAt(now)
        .expiration(expiryDate)
        .signWith(key)
        .compact();
  }

  /**
   * Generate a refresh token.
   */
  public String generateRefreshToken(UUID userId) {
    Date now = new Date();
    Date expiryDate = new Date(now.getTime() + refreshExpiration);

    return Jwts.builder()
        .subject(userId.toString())
        .issuedAt(now)
        .expiration(expiryDate)
        .signWith(key)
        .compact();
  }

  /**
   * Extract user ID from token.
   */
  public UUID getUserIdFromToken(String token) {
    Claims claims = parseToken(token);
    return UUID.fromString(claims.getSubject());
  }

  /**
   * Extract role from token.
   */
  public String getRoleFromToken(String token) {
    Claims claims = parseToken(token);
    return claims.get("role", String.class);
  }

  /**
   * Validate a token.
   */
  public boolean validateToken(String token) {
    try {
      parseToken(token);
      return true;
    } catch (JwtException | IllegalArgumentException e) {
      return false;
    }
  }

  private Claims parseToken(String token) {
    return Jwts.parser()
        .verifyWith(key)
        .build()
        .parseSignedClaims(token)
        .getPayload();
  }
}
