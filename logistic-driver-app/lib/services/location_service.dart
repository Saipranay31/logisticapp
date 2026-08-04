import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'api_service.dart';
import 'websocket_service.dart';

/// Service to handle driver location tracking during active rides
/// ✅ PHASE 6: WebSocket-based location broadcasting every 5 seconds
class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _locationSendTimer;
  bool _isTracking = false;
  bool _isSending = false; // 🔴 FIX: Prevent overlapping sends
  String? _currentRideId;
  String? _driverId;
  Position? _lastPosition;

  Future<void> initialize() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }
  }

  /// ✅ PHASE 6: Start tracking driver location with WebSocket broadcast
  /// Sends location updates every 5 seconds (3x more frequent than before)
  Future<void> startTracking(String rideId, {String? driverId}) async {
    if (_isTracking) {
      stopTracking();
    }

    _currentRideId = rideId;
    _driverId = driverId;
    _isTracking = true;

    try {
      // Request permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      // Listen to location updates continuously
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0, // Get updates as frequently as possible
          timeLimit: Duration(seconds: 30),
        ),
      ).listen((Position position) {
        _lastPosition = position;
      });

      // ✅ PHASE 6: Send location every 5 seconds via WebSocket (was 15s polling)
      _locationSendTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (_isTracking && _currentRideId != null) {
          await _sendLocationUpdateViaWebSocket();
        }
      });

      // Also send immediately
      await _sendLocationUpdateViaWebSocket();
      print('📍 Location tracking started for ride: $rideId (WebSocket, 5s interval)');
    } catch (e) {
      print('❌ Error starting location tracking: $e');
      _isTracking = false;
    }
  }

  /// Stop tracking and sending location updates
  void stopTracking() {
    _isTracking = false;
    _currentRideId = null;
    _positionStream?.cancel();
    _locationSendTimer?.cancel();
    print('🛑 Location tracking stopped');
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      print('📍 Location permission status: $permission');

      if (permission == LocationPermission.denied) {
        print('⚠️ Permission denied, requesting...');
        final newPermission = await Geolocator.requestPermission();
        print('📍 After request: $newPermission');
        if (newPermission == LocationPermission.denied || newPermission == LocationPermission.deniedForever) {
          print('❌ Location permission rejected');
          return null;
        }
      }

      print('📍 Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
      print('✅ Got position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting current location: $e');
      return null;
    }
  }

  /// ✅ Send location update via WebSocket (with REST fallback)
  /// Broadcasts to /app/driver/location which backend processes and re-broadcasts to users
  Future<void> _sendLocationUpdateViaWebSocket() async {
    if (_currentRideId == null) {
      print('⚠️ No ride ID set, skipping location update');
      return;
    }

    // 🔴 FIX: Prevent overlapping sends that cause OptimisticLockingFailure
    if (_isSending) {
      print('⏳ Previous location send still in progress, skipping');
      return;
    }
    _isSending = true;

    try {
      final position = _lastPosition ?? await getCurrentLocation();
      if (position == null) {
        print('⚠️ Could not get current position');
        return;
      }

      _lastPosition = position;

      // Build location message for WebSocket
      final locationMessage = {
        'rideId': _currentRideId,
        'driverId': _driverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'bearing': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      print('📡 Broadcasting location: lat=${position.latitude}, lng=${position.longitude}');

      // Send via WebSocket to backend
      try {
        await WebSocketService.sendMessage(
          destination: '/app/driver/location',
          body: jsonEncode(locationMessage),
        );
        print('✅ WebSocket location sent successfully');
      } catch (wsError) {
        print('⚠️ WebSocket send failed: $wsError, falling back to REST API');
        // Fallback to REST API if WebSocket not available
        await _sendLocationUpdateViaRest(position);
      }
    } catch (e) {
      print('❌ Error sending location: $e');
    } finally {
      _isSending = false;
    }
  }

  /// Fallback: Send location update via REST API if WebSocket unavailable
  Future<void> _sendLocationUpdateViaRest(Position position) async {
    try {
      if (_currentRideId == 'ONLINE') {
        // Driver is online (not on a ride)
        await ApiService.updateDriverOnlineLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          heading: position.heading,
        );
      } else {
        // Driver is on a ride
        await ApiService.sendDriverLocation(
          rideId: _currentRideId!,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          heading: position.heading,
          accuracy: position.accuracy,
          altitude: position.altitude,
        );
      }
      print('✅ REST API location fallback sent');
    } catch (e) {
      print('❌ REST API fallback also failed: $e');
    }
  }

  bool get isTracking => _isTracking;
  String? get currentRideId => _currentRideId;
}
