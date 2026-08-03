package com.porter.file.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import lombok.Getter;
import lombok.Setter;

@Component
@ConfigurationProperties(prefix = "porter.storage")
@Getter
@Setter
public class StorageConfig {
    // ✅ FIXED: Read from application.yml (no hardcoded defaults)
    private String basePath;  // Read from application.yml: porter.storage.base-path
    private String driverImagesPath;  // Read from application.yml: porter.storage.driver-images-path
    private String kycDocumentsPath;  // Read from application.yml: porter.storage.kyc-documents-path
    private long maxFileSize = 5242880; // 5MB default
    private String allowedFileTypes = "jpg,jpeg,png,pdf";

    public String getFullPath(String relativePath) {
        // ✅ Use forward slashes for cross-platform compatibility
        return basePath + "/" + relativePath;
    }
}
