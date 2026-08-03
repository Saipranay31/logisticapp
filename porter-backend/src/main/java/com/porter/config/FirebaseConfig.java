package com.porter.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;

/**
 * Firebase configuration for FCM push notifications.
 * Reads credentials from file path (filesystem or classpath).
 * If no credentials file is found, FCM is disabled gracefully.
 */
@Configuration
@Slf4j
public class FirebaseConfig {

  @Value("${firebase.credentials-path:firebase-key.json}")
  private String credentialsPath;

  @PostConstruct
  public void init() {
    try {
      InputStream serviceAccount = null;

      // Try filesystem first
      File file = new File(credentialsPath);
      if (file.exists()) {
        serviceAccount = new FileInputStream(file);
        log.info("Firebase credentials loaded from filesystem: {}", credentialsPath);
      } else {
        // Try classpath
        try {
          ClassPathResource resource = new ClassPathResource(credentialsPath);
          if (resource.exists()) {
            serviceAccount = resource.getInputStream();
            log.info("Firebase credentials loaded from classpath: {}", credentialsPath);
          }
        } catch (Exception ignored) {
        }
      }

      if (serviceAccount != null) {
        FirebaseOptions options = FirebaseOptions.builder()
            .setCredentials(GoogleCredentials.fromStream(serviceAccount))
            .build();

        if (FirebaseApp.getApps().isEmpty()) {
          FirebaseApp.initializeApp(options);
          log.info("✅ Firebase initialized successfully — FCM enabled");
        }
      } else {
        log.warn("⚠️ Firebase credentials not found at '{}' — FCM push disabled, using WebSocket only",
            credentialsPath);
      }
    } catch (Exception e) {
      log.warn("⚠️ Firebase initialization failed: {} — FCM push disabled", e.getMessage());
    }
  }
}
