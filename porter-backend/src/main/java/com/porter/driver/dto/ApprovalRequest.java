package com.porter.driver.dto;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ApprovalRequest {
    private String adminNotes;
    private Boolean approved;
    private String rejectionReason;
}
