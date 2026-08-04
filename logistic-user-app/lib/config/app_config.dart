import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration — all values loaded from .env at runtime.
/// Never hardcode secrets or URLs directly in source code.
class AppConfig {
  // ── API ───────────────────────────────────────────────────────────────────
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://lou-tremendous-night-century.trycloudflare.com/api';

  static String get fileServerUrl =>
      dotenv.env['FILE_SERVER_URL'] ?? dotenv.env['BASE_URL']
        ?.replaceFirst(RegExp(r'/api$'), '') ?? 'https://lou-tremendous-night-century.trycloudflare.com:8081';

  /// WebSocket URL derived from baseUrl automatically.
  /// https://host/api → wss://host/ws
  /// http://host:port/api → ws://host:port/ws
  static String get wsUrl => baseUrl
      .replaceFirst(RegExp(r'^https://'), 'wss://')
      .replaceFirst(RegExp(r'^http://'), 'ws://')
      .replaceFirst(RegExp(r'/api$'), '/ws');

  // ── Firebase Config ───────────────────────────────────────────────────────
  static const String firebaseProjectId = 'porter-project';

  // ── Google Maps ───────────────────────────────────────────────────────────
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ── Razorpay ──────────────────────────────────────────────────────────────
  static String get razorpayKeyId =>
      dotenv.env['RAZORPAY_KEY_ID'] ?? '';

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName    = 'Porter';
  static const String appVersion = '1.0.0';
  static const String userRole   = 'USER';

  // ── Feature Flags ─────────────────────────────────────────────────────────
  static bool get enableDebugLogging =>
      dotenv.env['ENABLE_DEBUG_LOGGING'] == 'true';
  static const bool enableCrashReporting = false;
  static const int  apiTimeoutSeconds    = 30;

  /// Convert relative file path to absolute URL.
  /// Handles new-style (/api/files/...), legacy Windows paths, and full URLs.
  static String getFileUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    if (relativePath.startsWith('http')) return relativePath;
    // New format: /api/files/... (FileStorageService current output)
    if (relativePath.startsWith('/api/')) {
      return fileServerUrl + relativePath;
    }
    // Legacy DB format: /files/... (old records stored without /api prefix).
    // FileController is mounted at /api/files, so prepend /api.
    if (relativePath.startsWith('/files/')) {
      debugPrint('🖼️ getFileUrl: legacy /files/ path → adding /api prefix: $relativePath');
      return fileServerUrl + '/api' + relativePath;
    }
    // Normalize Windows backslashes → forward slashes before pattern matching
    final normalized = relativePath.replaceAll('\\', '/');
    // Legacy Windows filesystem paths — extract category/filename
    for (final cat in ['drivers', 'users', 'kyc-documents', 'kyc', 'profile']) {
      final idx = normalized.lastIndexOf('/$cat/');
      if (idx != -1) {
        return '$fileServerUrl/api/files${normalized.substring(idx)}';
      }
    }
    if (normalized.startsWith('/')) return fileServerUrl + normalized;
    return relativePath;
  }
}
