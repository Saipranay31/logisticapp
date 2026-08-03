package com.porter.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;

/**
 * Async configuration.
 * Provides a dedicated thread pool and scheduler for driver matching,
 * separate from Spring's default async executor.
 */
@Configuration
@EnableAsync
public class AsyncConfig {

  /**
   * Fix 6: Dedicated thread pool for matching tasks.
   * Allows up to 30 concurrent ride-matching operations.
   */
  @Bean(name = "matchingExecutor")
  public Executor matchingExecutor() {
    ThreadPoolTaskExecutor exec = new ThreadPoolTaskExecutor();
    exec.setCorePoolSize(15);
    exec.setMaxPoolSize(30);
    exec.setQueueCapacity(100);
    exec.setThreadNamePrefix("matching-");
    exec.setWaitForTasksToCompleteOnShutdown(true);
    exec.setAwaitTerminationSeconds(60);
    exec.initialize();
    return exec;
  }

  /**
   * Fix 6: Shared scheduler for ride acceptance polling.
   * A single pool of scheduler threads handles all active-ride polls,
   * so matching threads are freed from sleeping and only await a Future.
   */
  @Bean(name = "matchingScheduler")
  public ScheduledExecutorService matchingScheduler() {
    return Executors.newScheduledThreadPool(6,
        r -> {
          Thread t = new Thread(r, "match-poll-" + System.nanoTime());
          t.setDaemon(true);
          return t;
        });
  }
}
