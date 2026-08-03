package com.porter.admin.controller;

import com.porter.admin.dto.DashboardDto;
import com.porter.admin.dto.DriverAnalyticsDto;
import com.porter.admin.dto.UserDetailDto;
import com.porter.admin.service.AdminService;
import com.porter.auth.service.RateLimitService;
import com.porter.common.dto.ApiResponse;
import com.porter.driver.dto.DriverProfileDto;
import com.porter.driver.entity.DriverDocument;
import com.porter.emergency.entity.EmergencyAlert;
import com.porter.emergency.service.EmergencyService;
import com.porter.ride.dto.RideDto;
import com.porter.ride.entity.RideDispute;
import com.porter.ride.service.DisputeService;
import com.porter.support.entity.SupportTicket;
import com.porter.support.entity.TicketMessage;
import com.porter.support.service.SupportTicketService;
import com.porter.user.dto.UserProfileDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

  private final AdminService adminService;
  private final DisputeService disputeService;
  private final EmergencyService emergencyService;
  private final SupportTicketService supportTicketService;
  private final RateLimitService rateLimitService;

  @GetMapping("/dashboard")
  public ResponseEntity<ApiResponse<DashboardDto>> getDashboard() {
    return ResponseEntity.ok(ApiResponse.success(adminService.getDashboard()));
  }

  // ─── DRIVERS ───

  @GetMapping("/drivers")
  public ResponseEntity<ApiResponse<List<DriverProfileDto>>> getAllDrivers() {
    return ResponseEntity.ok(ApiResponse.success(adminService.getAllDrivers()));
  }

  @PostMapping("/drivers/{userId}/activate")
  public ResponseEntity<ApiResponse<Void>> activateDriver(@PathVariable UUID userId) {
    adminService.setDriverActive(userId, true);
    return ResponseEntity.ok(ApiResponse.success("Driver activated", null));
  }

  @PostMapping("/drivers/{userId}/suspend")
  public ResponseEntity<ApiResponse<Void>> suspendDriver(@PathVariable UUID userId) {
    adminService.setDriverActive(userId, false);
    return ResponseEntity.ok(ApiResponse.success("Driver suspended", null));
  }

  @GetMapping("/drivers/{userId}/analytics")
  public ResponseEntity<ApiResponse<DriverAnalyticsDto>> getDriverAnalytics(@PathVariable UUID userId) {
    return ResponseEntity.ok(ApiResponse.success(adminService.getDriverAnalytics(userId)));
  }

  @GetMapping("/drivers/{userId}/documents")
  public ResponseEntity<ApiResponse<List<DriverDocument>>> getDriverDocuments(@PathVariable UUID userId) {
    return ResponseEntity.ok(ApiResponse.success(adminService.getDriverDocuments(userId)));
  }

  @PostMapping("/drivers/{userId}/kyc")
  public ResponseEntity<ApiResponse<DriverProfileDto>> approveDriverKyc(
      @PathVariable UUID userId, @RequestParam boolean approve) {
    return ResponseEntity.ok(ApiResponse.success(adminService.approveDriverKyc(userId, approve)));
  }

  // ─── USERS ───

  @GetMapping("/users")
  public ResponseEntity<ApiResponse<List<UserProfileDto>>> getAllUsers() {
    return ResponseEntity.ok(ApiResponse.success(adminService.getAllUsers()));
  }

  @GetMapping("/users/{userId}")
  public ResponseEntity<ApiResponse<UserDetailDto>> getUserDetail(@PathVariable UUID userId) {
    return ResponseEntity.ok(ApiResponse.success(adminService.getUserDetail(userId)));
  }

  @PostMapping("/users/{userId}/suspend")
  public ResponseEntity<ApiResponse<Void>> suspendUser(@PathVariable UUID userId) {
    adminService.setUserActive(userId, false);
    return ResponseEntity.ok(ApiResponse.success("User suspended", null));
  }

  @PostMapping("/users/{userId}/activate")
  public ResponseEntity<ApiResponse<Void>> activateUser(@PathVariable UUID userId) {
    adminService.setUserActive(userId, true);
    return ResponseEntity.ok(ApiResponse.success("User activated", null));
  }

  // ─── RIDES ───

  @GetMapping("/rides")
  public ResponseEntity<ApiResponse<List<RideDto>>> getAdminRides(
      @RequestParam(required = false, defaultValue = "ACTIVE") String status) {
    return ResponseEntity.ok(ApiResponse.success(adminService.getAdminRides(status)));
  }

  @GetMapping("/rides/active")
  public ResponseEntity<ApiResponse<List<RideDto>>> getActiveRides() {
    return ResponseEntity.ok(ApiResponse.success(adminService.getActiveRides()));
  }

  @GetMapping("/rides/{rideId}")
  public ResponseEntity<ApiResponse<RideDto>> getRideDetail(@PathVariable UUID rideId) {
    return ResponseEntity.ok(ApiResponse.success(adminService.getRideDetail(rideId)));
  }

  // ─── DISPUTES ───

  @GetMapping("/disputes")
  public ResponseEntity<ApiResponse<List<RideDispute>>> getAllDisputes() {
    return ResponseEntity.ok(ApiResponse.success(disputeService.getAllDisputes()));
  }

  @GetMapping("/disputes/open")
  public ResponseEntity<ApiResponse<List<RideDispute>>> getOpenDisputes() {
    return ResponseEntity.ok(ApiResponse.success(disputeService.getOpenDisputes()));
  }

  @PostMapping("/disputes/{disputeId}/resolve")
  public ResponseEntity<ApiResponse<RideDispute>> resolveDispute(
      @PathVariable UUID disputeId, @RequestBody Map<String, Object> body) {
    boolean approve = (boolean) body.getOrDefault("approve", false);
    String notes = (String) body.getOrDefault("notes", "");
    Double refundAmount = body.containsKey("refundAmount")
        ? ((Number) body.get("refundAmount")).doubleValue()
        : null;
    return ResponseEntity.ok(ApiResponse.success(
        disputeService.resolveDispute(disputeId, approve, notes, refundAmount)));
  }

  // ─── EMERGENCY ALERTS ───

  @GetMapping("/emergency/alerts")
  public ResponseEntity<ApiResponse<List<EmergencyAlert>>> getEmergencyAlerts() {
    return ResponseEntity.ok(ApiResponse.success(emergencyService.getOpenAlerts()));
  }

  @PostMapping("/emergency/alerts/{alertId}/acknowledge")
  public ResponseEntity<ApiResponse<EmergencyAlert>> acknowledgeAlert(@PathVariable UUID alertId) {
    return ResponseEntity.ok(ApiResponse.success(emergencyService.acknowledgeAlert(alertId)));
  }

  @PostMapping("/emergency/alerts/{alertId}/resolve")
  public ResponseEntity<ApiResponse<EmergencyAlert>> resolveAlert(@PathVariable UUID alertId) {
    return ResponseEntity.ok(ApiResponse.success(emergencyService.resolveAlert(alertId)));
  }

  // ─── SUPPORT TICKETS ───

  @GetMapping("/support/tickets")
  public ResponseEntity<ApiResponse<List<SupportTicket>>> getAllTickets() {
    return ResponseEntity.ok(ApiResponse.success(supportTicketService.getAllTickets()));
  }

  @GetMapping("/support/tickets/open")
  public ResponseEntity<ApiResponse<List<SupportTicket>>> getOpenTickets() {
    return ResponseEntity.ok(ApiResponse.success(supportTicketService.getOpenTickets()));
  }

  @PostMapping("/support/tickets/{ticketId}/resolve")
  public ResponseEntity<ApiResponse<SupportTicket>> resolveTicket(@PathVariable UUID ticketId) {
    return ResponseEntity.ok(ApiResponse.success(supportTicketService.resolveTicket(ticketId)));
  }

  @PostMapping("/support/tickets/{ticketId}/assign")
  public ResponseEntity<ApiResponse<SupportTicket>> assignTicket(
      @PathVariable UUID ticketId, @RequestParam UUID adminId) {
    return ResponseEntity.ok(ApiResponse.success(supportTicketService.assignTicket(ticketId, adminId)));
  }

  @PostMapping("/support/tickets/{ticketId}/reply")
  public ResponseEntity<ApiResponse<TicketMessage>> adminReply(
      Authentication auth, @PathVariable UUID ticketId,
      @RequestBody Map<String, Object> body) {
    UUID adminId = UUID.fromString(auth.getName());
    @SuppressWarnings("unchecked")
    List<String> attachments = body.containsKey("attachments")
        ? (List<String>) body.get("attachments")
        : null;
    return ResponseEntity.ok(ApiResponse.success(
        supportTicketService.addMessage(ticketId, adminId,
            (String) body.get("message"), "ADMIN", attachments)));
  }

  // ─── ACCOUNT MANAGEMENT ───

  @PostMapping("/accounts/{phone}/unlock")
  public ResponseEntity<ApiResponse<Void>> unlockAccount(@PathVariable String phone) {
    rateLimitService.unlockAccount(phone);
    return ResponseEntity.ok(ApiResponse.success("Account unlocked", null));
  }
}
