package com.porter.auth.repository;

import com.porter.auth.entity.OtpAttemptLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface OtpAttemptLogRepository extends JpaRepository<OtpAttemptLog, UUID> {
  List<OtpAttemptLog> findByPhoneAndAttemptTypeAndAttemptedAtAfter(
      String phone, String attemptType, LocalDateTime after);

  List<OtpAttemptLog> findByPhoneAndAttemptTypeAndStatusAndAttemptedAtAfter(
      String phone, String attemptType, String status, LocalDateTime after);
}
