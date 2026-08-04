import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration — all values loaded from .env at runtime.
/// Never hardcode secrets or URLs directly in source code.
class AppConfig {
  // ── API ───────────────────────────────────────────────────────────────────
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:8081/api';

  // ── Firebase Config ───────────────────────────────────────────────────────
  static const String firebaseProjectId = 'porter-project';
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName    = 'Porter Admin';
  static const String appVersion = '1.0.0';
  static const String adminRole  = 'ADMIN';

  // ── Feature Flags ─────────────────────────────────────────────────────────
  static bool get enableDebugLogging =>
      dotenv.env['ENABLE_DEBUG_LOGGING'] == 'true';
  static const bool enableCrashReporting = false;
  static const int  apiTimeoutSeconds    = 30;
}
