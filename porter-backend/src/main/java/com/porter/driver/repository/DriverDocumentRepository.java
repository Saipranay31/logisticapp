package com.porter.driver.repository;

import com.porter.driver.entity.DriverDocument;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface DriverDocumentRepository extends JpaRepository<DriverDocument, UUID> {
  List<DriverDocument> findByDriverProfileId(UUID driverProfileId);
  Page<DriverDocument> findByStatus(String status, Pageable pageable);
  List<DriverDocument> findByStatus(String status);
}
