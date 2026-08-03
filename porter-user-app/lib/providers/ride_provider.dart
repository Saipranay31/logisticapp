import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RideProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentRide;
  List<Map<String, dynamic>> _rideHistory = [];
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get currentRide => _currentRide;
  List<Map<String, dynamic>> get rideHistory => _rideHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 🔴 CRITICAL FIX: Accept and use actual coordinates from booking screen
  Future<bool> createRide(
    String pickup,
    String drop,
    String vehicleType, {
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropLatitude,
    double? dropLongitude,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.createRide(
        pickupAddress: pickup,
        dropAddress: drop,
        vehicleType: vehicleType,
        pickupLatitude: pickupLatitude ?? 28.6139,
        pickupLongitude: pickupLongitude ?? 77.2090,
        dropLatitude: dropLatitude ?? (pickupLatitude ?? 28.6139) + 0.1,
        dropLongitude: dropLongitude ?? (pickupLongitude ?? 77.2090) + 0.1,
      );
      _currentRide = {
        'id': res.id,
        'userId': res.userId,
        'status': res.status,
        'pickupAddress': res.pickupAddress,
        'dropAddress': res.dropAddress,
        'estimatedFare': res.estimatedFare,
        'actualFare': res.actualFare,
        'vehicleType': res.vehicleType,
        'driverId': res.driverId,
        'driverName': res.driverName,
        'driverRating': res.driverRating,
        'driverPhone': res.driverPhone,
        'driverImage': res.driverImage,
        'vehicleNumber': res.vehicleNumber,
        'pickupLatitude': res.pickupLatitude,
        'pickupLongitude': res.pickupLongitude,
        'dropLatitude': res.dropLatitude,
        'dropLongitude': res.dropLongitude,
      };
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelRide(dynamic rideId) async {
    try {
      await ApiService.cancelRide(rideId.toString());
      _currentRide = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchRideHistory() async {
    _isLoading = true; notifyListeners();
    try {
      final rides = await ApiService.getUserRideHistory();
      _rideHistory = rides.map<Map<String, dynamic>>((r) => {
        'id': r.id,
        'status': r.status,
        'pickupAddress': r.pickupAddress,
        'dropAddress': r.dropAddress,
        'estimatedFare': r.estimatedFare,
        'actualFare': r.actualFare,
        'vehicleType': r.vehicleType,
        'driverId': r.driverId,
        'driverName': r.driverName,
        'createdAt': r.createdAt?.toIso8601String() ?? '',
      }).toList();
    } catch (_) {}
    _isLoading = false; notifyListeners();
  }

  /// Fetch the status of the current active ride from backend
  Future<void> refreshCurrentRide() async {
    if (_currentRide == null || _currentRide!['id'] == null) return;
    try {
      final res = await ApiService.getRide(_currentRide!['id'].toString());
      _currentRide = {
        'id': res.id,
        'userId': res.userId,
        'status': res.status,
        'pickupAddress': res.pickupAddress,
        'dropAddress': res.dropAddress,
        'estimatedFare': res.estimatedFare,
        'actualFare': res.actualFare,
        'vehicleType': res.vehicleType,
        'driverId': res.driverId,
        'driverName': res.driverName,
        'driverRating': res.driverRating,
        'driverPhone': res.driverPhone,
        'driverImage': res.driverImage,
        'vehicleNumber': res.vehicleNumber,
        'pickupLatitude': res.pickupLatitude,
        'pickupLongitude': res.pickupLongitude,
        'dropLatitude': res.dropLatitude,
        'dropLongitude': res.dropLongitude,
      };
      notifyListeners();
    } catch (_) {}
  }

  void updateCurrentRide(Map<String, dynamic> data) {
    _currentRide = data;
    notifyListeners();
  }

  void clearRide() {
    _currentRide = null;
    notifyListeners();
  }
}
