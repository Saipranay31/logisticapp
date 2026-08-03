import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AdminProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token, _error;
  Map<String, dynamic>? _dashboard;
  bool _isLoading = false;

  String? get token => _token;
  String? get error => _error;
  Map<String, dynamic>? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<bool> checkAuth() async {
    try {
      _token = await _storage.read(key: 'token');
    } catch (_) {
      // Keystore corruption (e.g. after reinstall) — wipe and force re-login
      await _storage.deleteAll();
      _token = null;
    }
    if (_token != null) { ApiService.setToken(_token!); notifyListeners(); return true; }
    return false;
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      final r = await ApiService.adminLogin(email, password);
      _token = r.accessToken;
      await _storage.write(key: 'token', value: _token);
      ApiService.setToken(_token!);
      notifyListeners();
      return true;
    } catch (e) { _error = e.toString(); return false; }
  }

  Future<void> fetchDashboard() async {
    _isLoading = true; notifyListeners();
    try {
      final r = await ApiService.getDashboard();
      _dashboard = Map<String, dynamic>.from(r);
    } catch (_) {
      _dashboard = {
        'activeDrivers': 0, 'totalUsers': 0, 'totalDrivers': 0,
        'todayRides': 0, 'totalRides': 0, 'activeRides': 0, 'completedRides': 0,
        'totalRevenue': 0.0, 'todayRevenue': 0.0,
      };
    }
    _isLoading = false; notifyListeners();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _token = null; _dashboard = null;
    ApiService.setToken('');
    notifyListeners();
  }
}
