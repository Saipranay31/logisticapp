package com.porter.file.controller;

import com.porter.file.config.StorageConfig;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@RestController
@RequestMapping("/api/files")
@RequiredArgsConstructor
@Slf4j
public class FileController {

    private final StorageConfig storageConfig;

    // ✅ IMPORTANT: Public file endpoint - no authentication required
    @GetMapping("/{directory}/{filename}")
    public ResponseEntity<Resource> serveFile(
            @PathVariable String directory,
            @PathVariable String filename) {
        try {
            // Construct file path safely
            Path filePath = Paths.get(storageConfig.getFullPath(directory), filename);

            log.info("📁 Serving file: directory={}, filename={}, fullPath={}", directory, filename, filePath.toString());

            // Ensure file is within allowed directory (prevent directory traversal)
            String normalizedPath = filePath.toRealPath().toString();
            String allowedPath = Paths.get(storageConfig.getFullPath(directory)).toRealPath().toString();
            if (!normalizedPath.startsWith(allowedPath)) {
                log.warn("❌ Directory traversal attempt: {}", normalizedPath);
                return ResponseEntity.badRequest().build();
            }

            if (!Files.exists(filePath)) {
                log.warn("⚠️ File not found at: {}", filePath.toString());
                return ResponseEntity.notFound().build();
            }

            log.info("✅ File found: {}, size: {} bytes", filePath.toString(), Files.size(filePath));
            Resource resource = new FileSystemResource(filePath);
            String mediaType = getMediaType(filename);

            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + filename + "\"")
                    .header(HttpHeaders.CONTENT_TYPE, mediaType)
                    .body(resource);
        } catch (Exception e) {
            log.error("❌ Error serving file: {}/{}", directory, filename, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    private String getMediaType(String filename) {
        if (filename.endsWith(".jpg") || filename.endsWith(".jpeg")) {
            return "image/jpeg";
        } else if (filename.endsWith(".png")) {
            return "image/png";
        } else if (filename.endsWith(".pdf")) {
            return "application/pdf";
        }
        return "application/octet-stream";
    }
}
