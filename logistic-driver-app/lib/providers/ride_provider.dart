import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class RideProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentRide;
  List<Map<String, dynamic>> _rideHistory = [];
  bool _isLoading = false;
  String? _error;
  BuildContext? _navContext;

  Map<String, dynamic>? get currentRide => _currentRide;
  List<Map<String, dynamic>> get rideHistory => _rideHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Set a context for navigation (call from active delivery screen)
  void setNavContext(BuildContext ctx) => _navContext = ctx;

  Map<String, dynamic> _rideToMap(RideData r) => {
    'id': r.id, 'status': r.status,
    'pickupAddress': r.pickupAddress, 'dropAddress': r.dropAddress,
    'pickupLatitude': r.pickupLatitude, 'pickupLongitude': r.pickupLongitude,
    'dropLatitude': r.dropLatitude, 'dropLongitude': r.dropLongitude,
    'estimatedFare': r.estimatedFare, 'actualFare': r.actualFare,
    'vehicleType': r.vehicleType, 'driverId': r.driverId, 'driverName': r.driverName,
    'estimatedDistance': r.estimatedDistance, 'estimatedDuration': r.estimatedDuration,
    'userName': r.userName, 'userPhone': r.userPhone,
    'paymentMethod': r.paymentMethod, 'paymentStatus': r.paymentStatus,
  };

  Future<bool> acceptRide(String rideId) async {
    print('🚀 RideProvider.acceptRide() called with rideId=$rideId');
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      print('📡 Calling ApiService.acceptRide...');
      final r = await ApiService.acceptRide(rideId);
      print('✅ ApiService returned: status=${r.status}, driverId=${r.driverId}');
      print('📍 RIDE DATA FROM API: pickupLat=${r.pickupLatitude}, pickupLng=${r.pickupLongitude}');
      print('📍 DROP DATA FROM API: dropLat=${r.dropLatitude}, dropLng=${r.dropLongitude}');
      _currentRide = _rideToMap(r);
      print('🔄 Updated currentRide: ${_currentRide}');
      print('🗺️ CURRENTRIDE COORDS: pickupLat=${_currentRide!['pickupLatitude']}, pickupLng=${_currentRide!['pickupLongitude']}');
      _isLoading = false;
      notifyListeners();

      // Subscribe to ride status updates for cancellation handling
      if (r.driverId != null) {
        _subscribeToRideStatusUpdates(r.driverId!);
      }

      return true;
    } catch (e) {
      print('❌ acceptRide error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Subscribe to WebSocket for ride CANCELLED/status updates
  void _subscribeToRideStatusUpdates(String driverId) {
    try {
      WebSocketService.subscribeToDriverRideUpdates(driverId, (data) {
        final status = data['status']?.toString();
        print('📡 Driver ride status update: $status');
        if (status == 'CANCELLED') {
          print('🚫 Ride cancelled by user! Clearing ride and navigating home.');
          _currentRide = null;
          notifyListeners();
          // Navigate to home if context is available
          if (_navContext != null) {
            try {
              Navigator.pushNamedAndRemoveUntil(_navContext!, '/home', (route) => false);
            } catch (_) {}
          }
        } else if (data is Map<String, dynamic>) {
          // Update current ride data for other status changes
          _currentRide?.addAll({'status': status});
          if (data['paymentMethod'] != null) {
            _currentRide?.addAll({'paymentMethod': data['paymentMethod']});
          }
          notifyListeners();
        }
      });
    } catch (e) {
      print('⚠️ Failed to subscribe to driver ride status: $e');
    }
  }

  Future<void> arriveAtPickup(String rideId) async {
    try {
      final r = await ApiService.driverArrived(rideId);
      _currentRide = _rideToMap(r);
    } catch (e) {
      _error = e.toString();
      rethrow;  // ✅ FIX: Re-throw so UI can catch the error
    }
    notifyListeners();
  }

  Future<void> startRide(String rideId, String otp) async {
    try {
      final r = await ApiService.startRide(rideId, otp);
      _currentRide = _rideToMap(r);
    } catch (e) {
      _error = e.toString();
      rethrow;  // ✅ FIX: Re-throw so UI can catch the error
    }
    notifyListeners();
  }

  Future<void> completeRide(String rideId) async {
    try {
      final r = await ApiService.completeRide(rideId);
      _currentRide = _rideToMap(r);
    } catch (e) { _error = e.toString(); }
    notifyListeners();
  }

  Future<void> toggleOnline(bool online, {double? lat, double? lng}) async {
    try { await ApiService.toggleOnlineStatus(online, latitude: lat, longitude: lng); }
    catch (e) { _error = e.toString(); }
  }

  Future<void> fetchHistory() async {
    _isLoading = true; notifyListeners();
    try {
      final rides = await ApiService.getDriverRideHistory();
      _rideHistory = rides.map((r) => _rideToMap(r)).toList();
    } catch (_) {}
    _isLoading = false; notifyListeners();
  }

  void updateCurrentRide(Map<String, dynamic> data) {
    _currentRide = data;
    notifyListeners();
  }

  void clearRide() { _currentRide = null; notifyListeners(); }
}
