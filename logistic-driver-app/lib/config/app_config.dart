import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration — all values loaded from .env at runtime.
/// Never hardcode secrets or URLs directly in source code.
class AppConfig {
  // ── API ───────────────────────────────────────────────────────────────────
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8081/api';

  /// WebSocket URL derived from baseUrl automatically.
  /// https://host/api → wss://host/ws
  /// http://host:port/api → ws://host:port/ws
  static String get wsUrl => baseUrl
      .replaceFirst(RegExp(r'^https://'), 'wss://')
      .replaceFirst(RegExp(r'^http://'), 'ws://')
      .replaceFirst(RegExp(r'/api$'), '/ws');

  // ── Google Maps ───────────────────────────────────────────────────────────
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ── Razorpay ──────────────────────────────────────────────────────────────
  static String get razorpayKeyId =>
      dotenv.env['RAZORPAY_KEY_ID'] ?? '';

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName    = 'Porter Driver';
  static const String appVersion = '1.0.0';
  static const String userRole   = 'DRIVER';

  // ── Feature Flags ─────────────────────────────────────────────────────────
  static bool get enableDebugLogging =>
      dotenv.env['ENABLE_DEBUG_LOGGING'] == 'true';
  static const bool enableCrashReporting = false;
  static const int  apiTimeoutSeconds    = 30;
}
