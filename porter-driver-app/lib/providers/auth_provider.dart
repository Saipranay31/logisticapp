import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token, _userId, _fullName, _phone, _role, _error, _driverProfileId;
  bool _isLoading = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get role => _role;
  String? get error => _error;
  String? get driverProfileId => _driverProfileId;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<bool> checkAuth() async {
    try {
      // ✅ FIX: Wrap in try-catch to handle BadPaddingException
      _token = await _storage.read(key: 'token');
      _userId = await _storage.read(key: 'userId');
      _fullName = await _storage.read(key: 'fullName');
      _phone = await _storage.read(key: 'phone');
      if (_token != null) {
        ApiService.setToken(_token!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      // ✅ FIX: Handle decryption errors gracefully
      print('⚠️ Secure storage error: $e');
      print('🗑️ Clearing corrupted secure storage...');
      await _clearAuth();  // Clear corrupted data
      return false;
    }
  }

  // ✅ NEW: Clear authentication data
  Future<void> _clearAuth() async {
    try {
      await _storage.deleteAll();
      _token = null;
      _userId = null;
      _fullName = null;
      _phone = null;
      notifyListeners();
    } catch (e) {
      print('❌ Error clearing storage: $e');
    }
  }

  Future<bool> sendOtp(String phone) async {
    _error = null;
    try { final r = await ApiService.sendOtp(phone, 'DRIVER'); return r['success'] == true; }
    catch (e) { _error = e.toString(); return false; }
  }

  Future<bool> verifyOtp(String phone, String otp, String role, [String? fullName]) async {
    _error = null;
    try {
      // ✅ SIMPLIFIED: Just OTP verification, no image upload
      final r = await ApiService.verifyOtp(phone, otp, role, fullName ?? 'Driver');
      _token = r.accessToken;
      _userId = r.userId;
      _fullName = r.fullName;
      _phone = phone;
      await _storage.write(key: 'token', value: _token);
      await _storage.write(key: 'userId', value: _userId);
      await _storage.write(key: 'fullName', value: _fullName ?? '');
      await _storage.write(key: 'phone', value: _phone);
      ApiService.setToken(_token!);

      // ✨ FIX #2: Register device token with backend for push notifications
      _registerDeviceToken();

      notifyListeners();
      return true;
    } catch (e) { _error = e.toString(); return false; }
  }

  // ✨ ENHANCED FIX: Register device token with retry logic
  Future<void> _registerDeviceToken() async {
    int maxRetries = 3;
    int delayMs = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔔 Device token registration attempt $attempt/$maxRetries...');

        final fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken == null) {
          print('⚠️ Attempt $attempt: FCM token is NULL - Firebase may not be initialized');
          if (attempt < maxRetries) {
            print('⏳ Waiting ${delayMs}ms before retry...');
            await Future.delayed(Duration(milliseconds: delayMs));
            delayMs *= 2; // Exponential backoff
          }
          continue;
        }

        print('✅ FCM token obtained: ${fcmToken.substring(0, 30)}...');
        await ApiService.registerDeviceToken(fcmToken);
        print('✅ Device token registered successfully with backend!');
        return; // Success - exit

      } catch (e) {
        print('❌ Attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          print('⏳ Waiting ${delayMs}ms before retry...');
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2; // Exponential backoff
        }
      }
    }

    print('⚠️ Failed to register device token after $maxRetries attempts');
    print('⚠️ Notifications will NOT work - check Firebase configuration and google-services.json');
  }

  // ✨ NEW: Fetch and cache driver profile ID
  Future<void> loadDriverProfile() async {
    try {
      final profile = await ApiService.getDriverProfile();
      _driverProfileId = profile.id;
      await _storage.write(key: 'driverProfileId', value: _driverProfileId ?? '');
      notifyListeners();
    } catch (e) {
      print('⚠️ Failed to load driver profile: $e');
    }
  }

  Future<void> updateFullName(String name) async {
    _fullName = name;
    await _storage.write(key: 'fullName', value: _fullName ?? '');
    notifyListeners();
  }

  Future<void> logout() async {
    try { await ApiService.removeDeviceToken(''); } catch (_) {}
    await _storage.deleteAll();
    _token = null; _userId = null; _fullName = null; _phone = null; _driverProfileId = null;
    ApiService.setToken(''); notifyListeners();
  }
}
