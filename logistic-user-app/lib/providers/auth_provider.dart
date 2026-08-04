import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  String? _userId;
  String? _fullName;
  String? _phone;
  String? _role;
  String? _error;
  bool _isLoading = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get role => _role;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<bool> checkAuth() async {
    try {
      _token = await _storage.read(key: 'token');
      _userId = await _storage.read(key: 'userId');
      _fullName = await _storage.read(key: 'fullName');
      _phone = await _storage.read(key: 'phone');
      _role = await _storage.read(key: 'role');
    } catch (e) {
      // BadPaddingException after reinstall — clear corrupted storage
      print('⚠️ Secure storage corrupted, clearing: $e');
      await _storage.deleteAll();
      _token = null;
      return false;
    }
    if (_token != null) {
      ApiService.setToken(_token!);
      notifyListeners();

      // ✅ Also register device token on app startup (cached session)
      await _registerDeviceToken();

      return true;
    }
    return false;
  }

  Future<bool> sendOtp(String phone) async {
    _error = null;
    try {
      final res = await ApiService.sendOtp(phone, 'USER');
      return res['success'] == true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Returns: null=error, false=existing user, true=new user
  Future<bool?> verifyOtp(String phone, String otp, String role, [String? fullName]) async {
    _error = null;
    try {
      final res = await ApiService.verifyOtp(phone, otp, role, fullName: fullName ?? 'User');
      _token = res.accessToken;
      _userId = res.userId;
      _fullName = res.fullName;
      _phone = phone;
      _role = res.role;
      await _storage.write(key: 'token', value: _token);
      await _storage.write(key: 'userId', value: _userId);
      await _storage.write(key: 'fullName', value: _fullName ?? '');
      await _storage.write(key: 'phone', value: _phone);
      await _storage.write(key: 'role', value: _role);
      ApiService.setToken(_token!);
      notifyListeners();

      // ✅ Register FCM device token after successful login
      await _registerDeviceToken();

      return res.isNewUser; // true=new user, false=existing
    } catch (e) {
      _error = e.toString();
      return null; // error
    }
  }

  Future<void> _registerDeviceToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await ApiService.registerDeviceToken(fcmToken, platform: 'ANDROID');
        print('✅ User device token registered: $fcmToken');
      }
    } catch (e) {
      print('❌ User device token registration failed: $e');
    }
  }

  void updateName(String name) {
    _fullName = name;
    _storage.write(key: 'fullName', value: name);
    notifyListeners();
  }

  Future<void> logout() async {
    try { await ApiService.removeDeviceToken(''); } catch (_) {}
    await _storage.deleteAll();
    _token = null; _userId = null; _fullName = null; _phone = null; _role = null;
    ApiService.setToken('');
    notifyListeners();
  }
}
