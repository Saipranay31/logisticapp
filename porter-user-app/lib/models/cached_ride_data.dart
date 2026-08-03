import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CachedRideData {
  static const _key = 'cached_ride_data';

  final String driverId;
  final String driverName;
  final String driverImage;
  final double driverRating;
  final String driverPhone;
  final String vehicleType;
  final String vehicleNumber;
  final String status;
  double? currentLat;
  double? currentLng;

  CachedRideData({
    required this.driverId,
    required this.driverName,
    required this.driverImage,
    required this.driverRating,
    required this.driverPhone,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.status,
    this.currentLat,
    this.currentLng,
  });

  // ── Persist to SharedPreferences ──────────────────────
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toMap()));
    } catch (e) {
      print('⚠️ CachedRideData.save() failed: $e');
    }
  }

  // ── Restore from SharedPreferences ────────────────────
  static Future<CachedRideData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CachedRideData(
        driverId:      map['driverId']      ?? '',
        driverName:    map['driverName']    ?? 'Driver',
        driverImage:   map['driverImage']   ?? '',
        driverRating:  (map['driverRating'] as num?)?.toDouble() ?? 4.5,
        driverPhone:   map['driverPhone']   ?? '',
        vehicleType:   map['vehicleType']   ?? 'CAR',
        vehicleNumber: map['vehicleNumber'] ?? '',
        status:        map['status']        ?? '',
        currentLat:    (map['driverLatitude']  as num?)?.toDouble(),
        currentLng:    (map['driverLongitude'] as num?)?.toDouble(),
      );
    } catch (e) {
      print('⚠️ CachedRideData.load() failed: $e');
      return null;
    }
  }

  // ── Wipe from disk on ride complete/cancel ─────────────
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  void updateLocation(double lat, double lng) {
    currentLat = lat;
    currentLng = lng;
    print('📍 CACHE UPDATE: Location updated to ($lat, $lng)');
  }

  bool locationChanged(double newLat, double newLng) {
    const threshold = 0.00005;
    return (newLat - (currentLat ?? 0)).abs() > threshold ||
        (newLng - (currentLng ?? 0)).abs() > threshold;
  }

  Map<String, dynamic> toMap() => {
    'driverId':        driverId,
    'driverName':      driverName,
    'driverImage':     driverImage,
    'driverRating':    driverRating,
    'driverPhone':     driverPhone,
    'vehicleType':     vehicleType,
    'vehicleNumber':   vehicleNumber,
    'status':          status,
    'driverLatitude':  currentLat,
    'driverLongitude': currentLng,
  };

  @override
  String toString() =>
      'CachedRideData{id=$driverId, name=$driverName, lat=$currentLat, lng=$currentLng}';
}