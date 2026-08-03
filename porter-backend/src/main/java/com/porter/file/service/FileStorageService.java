package com.porter.file.service;

import com.porter.file.config.StorageConfig;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class FileStorageService {

    private final StorageConfig storageConfig;

    public String saveFile(MultipartFile file, String directory) throws IOException {
        // Validate file
        validateFile(file);

        // Create directory if not exists
        Path dirPath = Paths.get(storageConfig.getFullPath(directory));
        Files.createDirectories(dirPath);

        // Generate unique filename
        String originalName = file.getOriginalFilename();
        String extension = getFileExtension(originalName);
        String filename = UUID.randomUUID() + "." + extension;

        // Save file
        Path filePath = dirPath.resolve(filename);
        file.transferTo(filePath.toFile());

        log.info("✅ File saved: {}/{}", directory, filename);
        // ✅ FIXED: Return correct API endpoint path /api/files/{directory}/{filename}
        return "/api/files/" + directory + "/" + filename;
    }

    public void deleteFile(String fileUrl) throws IOException {
        // Extract filename from URL: /api/files/kyc-documents/uuid.jpg or /files/kyc-documents/uuid.jpg
        String relativePath = fileUrl.replace("/api/files/", "").replace("/files/", "");
        Path filePath = Paths.get(storageConfig.getFullPath(""), relativePath);

        if (Files.exists(filePath)) {
            Files.delete(filePath);
            log.info("✅ File deleted: {}", fileUrl);
        } else {
            log.warn("⚠️ File not found for deletion: {}", fileUrl);
        }
    }

    private void validateFile(MultipartFile file) throws IOException {
        // Check file size
        if (file.getSize() > storageConfig.getMaxFileSize()) {
            throw new IOException("File size exceeds maximum allowed: " + storageConfig.getMaxFileSize() + " bytes");
        }

        // Check file type
        String extension = getFileExtension(file.getOriginalFilename());
        if (!storageConfig.getAllowedFileTypes().toLowerCase().contains(extension.toLowerCase())) {
            throw new IOException("File type not allowed: " + extension);
        }
    }

    private String getFileExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            return "bin";
        }
        return filename.substring(filename.lastIndexOf(".") + 1);
    }

    public boolean fileExists(String fileUrl) {
        // Extract filename from URL: /api/files/drivers/uuid.jpg or /files/drivers/uuid.jpg
        String relativePath = fileUrl.replace("/api/files/", "").replace("/files/", "");
        Path filePath = Paths.get(storageConfig.getFullPath(""), relativePath);
        return Files.exists(filePath);
    }
}
