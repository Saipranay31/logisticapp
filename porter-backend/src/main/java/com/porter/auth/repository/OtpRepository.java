package com.porter.auth.repository;

import com.porter.auth.entity.OtpRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface OtpRepository extends JpaRepository<OtpRecord, UUID> {
  Optional<OtpRecord> findTopByPhoneAndPurposeOrderByCreatedAtDesc(String phone, String purpose);
}
