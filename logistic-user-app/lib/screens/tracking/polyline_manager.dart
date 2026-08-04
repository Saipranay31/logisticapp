import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dead_reckoning_engine.dart'; // for haversineMetres

// ═══════════════════════════════════════════════════════════
//  POLYLINE MANAGER
// ═══════════════════════════════════════════════════════════

class PolylineManager {
  List<LatLng> _fullRoute = [];
  int _trimIndex = 0;

  bool get hasRoute => _fullRoute.isNotEmpty;

  void setRoute(List<LatLng> points) {
    _fullRoute = List.unmodifiable(points);
    _trimIndex = 0;
  }

  List<LatLng> trim(LatLng driverPos) {
    if (_fullRoute.isEmpty) return [];
    int closest = _trimIndex;
    double minDist = double.infinity;
    final searchEnd = math.min(_trimIndex + 60, _fullRoute.length);
    for (int i = _trimIndex; i < searchEnd; i++) {
      final d = haversineMetres(
        driverPos.latitude,
        driverPos.longitude,
        _fullRoute[i].latitude,
        _fullRoute[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    _trimIndex = closest;
    return _fullRoute.sublist(_trimIndex);
  }

  void clear() {
    _fullRoute = [];
    _trimIndex = 0;
  }
}
