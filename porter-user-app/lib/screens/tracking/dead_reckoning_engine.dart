import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ═══════════════════════════════════════════════════════════
//  MATH HELPERS
// ═══════════════════════════════════════════════════════════

double haversineMetres(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) * math.sin(dLng / 2);
  return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double bearingDeg(double lat1, double lng1, double lat2, double lng2) {
  final dLng = (lng2 - lng1) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2 * math.pi / 180);
  final x = math.cos(lat1 * math.pi / 180) * math.sin(lat2 * math.pi / 180) -
      math.sin(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

// ═══════════════════════════════════════════════════════════
//  DEAD RECKONING ENGINE
//  Predicts driver position between WebSocket updates using
//  last known speed + bearing. Fires every 100ms so the
//  marker moves continuously even without new WS packets.
// ═══════════════════════════════════════════════════════════

class DeadReckoningEngine {
  double lat;
  double lng;
  double bearing; // degrees 0–360
  double speedMs; // metres per second
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
    final dist = haversineMetres(lat, lng, newLat, newLng);
    final rawSpeed = dist / dtSec;
    speedMs = rawSpeed.clamp(0.0, 34.0); // cap at ~120 km/h
    if (rawSpeed < 34.0) {              // only update bearing if speed is sane
      bearing = bearingDeg(lat, lng, newLat, newLng);
    }
  }
  lat = newLat;
  lng = newLng;
  lastUpdate = now;
  active = true;
}

  LatLng predict() {
    if (!active || speedMs < 0.5) return LatLng(lat, lng);
    final elapsed =
        DateTime.now().difference(lastUpdate).inMilliseconds / 1000.0;
    final dt = elapsed.clamp(0.0, 5.0);
    final distM = speedMs * dt;
    const R = 6371000.0;
    final dLat = (distM * math.cos(bearing * math.pi / 180)) / R;
    final dLng = (distM * math.sin(bearing * math.pi / 180)) /
        (R * math.cos(lat * math.pi / 180));
    return LatLng(
      lat + dLat * 180 / math.pi,
      lng + dLng * 180 / math.pi,
    );
  }

  void reset() {
    speedMs = 0;
    active = false;
  }
}
