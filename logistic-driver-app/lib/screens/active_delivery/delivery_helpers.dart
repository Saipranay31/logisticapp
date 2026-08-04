import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';

// ── Math helpers ────────────────────────────────────────────────────────────

double haversineM(double la1, double ln1, double la2, double ln2) {
  const R = 6371000.0;
  final dLat = (la2 - la1) * math.pi / 180;
  final dLng = (ln2 - ln1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(la1 * math.pi / 180) *
          math.cos(la2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double bearingDeg(double la1, double ln1, double la2, double ln2) {
  final dLng = (ln2 - ln1) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(la2 * math.pi / 180);
  final x = math.cos(la1 * math.pi / 180) * math.sin(la2 * math.pi / 180) -
      math.sin(la1 * math.pi / 180) *
          math.cos(la2 * math.pi / 180) *
          math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

// ── Redis Location Broadcaster ───────────────────────────────────────────────

class RedisLocationBroadcaster {
  Timer?  _timer;
  String? _rideId;

  double _lat = 0, _lng = 0, _bearing = 0, _speedMs = 0;
  double _lastPushedLat = 0, _lastPushedLng = 0;

  bool get active => _timer?.isActive == true;

  void start(String rideId, String? driverId) {
    _rideId = rideId;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _push());
  }

  void updatePosition(double lat, double lng, double bearing, double speedMs) {
    _lat = lat; _lng = lng; _bearing = bearing; _speedMs = speedMs;
  }

  Future<void> _push() async {
    if (_rideId == null || _lat == 0) return;
    final movedM = haversineM(_lastPushedLat, _lastPushedLng, _lat, _lng);
    if (_lastPushedLat != 0 && movedM < 5.0) return;
    try {
      await ApiService.updateRideLocation(
        _rideId!, latitude: _lat, longitude: _lng,
        heading: _bearing, speed: _speedMs,
      );
      _lastPushedLat = _lat; _lastPushedLng = _lng;
    } catch (e) {
      debugPrint('⚠️ Redis push failed: $e');
    }
  }

  void stop() { _timer?.cancel(); _timer = null; }
}

// ── Dead Reckoning Engine ────────────────────────────────────────────────────

class DeadReckoningEngine {
  double lat, lng, bearing, speedMs;
  DateTime lastUpdate;
  bool active = false;

  DeadReckoningEngine({
    required this.lat,
    required this.lng,
    this.bearing = 0,
    this.speedMs = 0,
  }) : lastUpdate = DateTime.now();

  void updateFix(double newLat, double newLng) {
    final now = DateTime.now();
    final dtSec = now.difference(lastUpdate).inMilliseconds / 1000.0;
    if (dtSec > 0.1 && dtSec < 30) {
      final dist = haversineM(lat, lng, newLat, newLng);
      speedMs = dist / dtSec;
      bearing = bearingDeg(lat, lng, newLat, newLng);
    }
    lat = newLat; lng = newLng; lastUpdate = now; active = true;
  }

  LatLng predict() {
    if (!active || speedMs < 1.5) return LatLng(lat, lng);
    final staleSec = DateTime.now().difference(lastUpdate).inMilliseconds / 1000.0;
    if (staleSec > 3.0) { speedMs = 0; return LatLng(lat, lng); }
    final dt = staleSec.clamp(0.0, 1.0);
    final distM = speedMs * dt;
    const R = 6371000.0;
    final dLat = (distM * math.cos(bearing * math.pi / 180)) / R;
    final dLng = (distM * math.sin(bearing * math.pi / 180)) /
        (R * math.cos(lat * math.pi / 180));
    return LatLng(lat + dLat * 180 / math.pi, lng + dLng * 180 / math.pi);
  }

  void reset() { speedMs = 0; active = false; }
}

// ── Polyline Manager ─────────────────────────────────────────────────────────

class PolylineManager {
  List<LatLng> _full = [];
  int _trimIdx = 0;

  bool get hasRoute => _full.isNotEmpty;

  void setRoute(List<LatLng> pts) {
    _full = List.unmodifiable(pts);
    _trimIdx = 0;
  }

  List<LatLng> trim(LatLng pos) {
    if (_full.isEmpty) return [];
    int closest = _trimIdx;
    double minD = double.infinity;
    final end = math.min(_trimIdx + 60, _full.length);
    for (int i = _trimIdx; i < end; i++) {
      final d = haversineM(
          pos.latitude, pos.longitude,
          _full[i].latitude, _full[i].longitude);
      if (d < minD) { minD = d; closest = i; }
    }
    _trimIdx = closest;
    return _full.sublist(_trimIdx);
  }

  void clear() { _full = []; _trimIdx = 0; }
}
