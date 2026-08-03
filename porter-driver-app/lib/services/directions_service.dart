import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_config.dart';

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final List<dynamic> steps;

  DirectionsResult({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.steps,
  });
}

/// Service to fetch turn-by-turn directions using Google Maps Directions API
class DirectionsService {
  static String get _apiKey => AppConfig.googleMapsApiKey;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetch directions between two points
  static Future<DirectionsResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // ✅ Validate coordinates before making API call
    if (originLat == 0.0 || originLng == 0.0 || destLat == 0.0 || destLng == 0.0) {
      print('❌ Invalid coordinates - Origin($originLat,$originLng) Dest($destLat,$destLng)');
      return null; // Return null for invalid coordinates
    }

    final String url = '$_baseUrl'
        '?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '&key=$_apiKey'
        '&mode=driving';

    try {
      print('🌐 Directions API URL: $url');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Directions API timeout'),
      );

      print('🌐 Directions API Status Code: ${response.statusCode}');
      print('🌐 Directions API Response: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // ✅ Check for API status
        if (json['status'] != 'OK') {
          print('❌ Directions API Error Status: ${json['status']}');
          print('❌ Error Message: ${json['error_message'] ?? 'No error message'}');
          return null;
        }

        if (json['routes'] == null || json['routes'].isEmpty) {
          print('❌ No routes found in response');
          return null;
        }

        final route = json['routes'][0];
        final leg = route['legs'][0];

        // Decode polyline points
        final polylinePoints = _decodePolyline(route['overview_polyline']['points']);

        return DirectionsResult(
          polylinePoints: polylinePoints,
          distance: leg['distance']['text'] ?? 'Unknown',
          duration: leg['duration']['text'] ?? 'Unknown',
          steps: leg['steps'] ?? [],
        );
      } else {
        print('❌ API returned status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Directions API error: $e');
      return null; // Return null instead of rethrowing
    }
  }

  /// Decode polyline string to list of LatLng points
  /// Using Google's polyline algorithm
  static List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < polyline.length) {
      int result = 0, shift = 0;
      int byte;

      do {
        byte = polyline.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;

      do {
        byte = polyline.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng((lat / 1e5).toDouble(), (lng / 1e5).toDouble()));
    }

    return points;
  }

  /// Get next turn instruction from directions steps
  static String getNextTurnInstruction(List<dynamic> steps, int currentStepIndex) {
    if (currentStepIndex >= steps.length) {
      return 'Arriving at destination';
    }

    final step = steps[currentStepIndex];
    final instruction = step['html_instructions'] ?? '';

    // Remove HTML tags
    return instruction.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Get step distance and duration
  static Map<String, String> getStepInfo(dynamic step) {
    return {
      'distance': step['distance']['text'] ?? 'Unknown',
      'duration': step['duration']['text'] ?? 'Unknown',
    };
  }
}
