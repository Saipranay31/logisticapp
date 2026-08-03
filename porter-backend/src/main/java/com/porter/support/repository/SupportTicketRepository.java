package com.porter.support.repository;

import com.porter.support.entity.SupportTicket;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SupportTicketRepository extends JpaRepository<SupportTicket, UUID> {
  List<SupportTicket> findByUserIdOrderByCreatedAtDesc(UUID userId);

  List<SupportTicket> findByStatusOrderByCreatedAtAsc(String status);

  List<SupportTicket> findAllByOrderByCreatedAtDesc();

  // Analytics
  long countByStatus(String status);
}
