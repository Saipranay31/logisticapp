import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });
}

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  static late String _apiKey;
  static final Map<String, List<PlacePrediction>> _predictionCache = {};

  /// Initialize the Places service with API key from AppConfig
  static Future<void> initialize() async {
    _apiKey = AppConfig.googleMapsApiKey;
    print('✅ PlacesService initialized with API key');
  }

  /// Search for place predictions based on user input
  /// Returns cached results if available, otherwise queries Google Places API
  static Future<List<PlacePrediction>> getPlacePredictions(String input, String sessionToken) async {
    if (input.isEmpty) return [];

    // Check cache first
    if (_predictionCache.containsKey(input)) {
      print('📦 Using cached predictions for "$input"');
      return _predictionCache[input]!;
    }

    try {
      final String url =
          '$_baseUrl/autocomplete/json?input=$input&key=$_apiKey&sessiontoken=$sessionToken&components=country:IN';

      print('🔍 Searching for locations: "$input"');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = <PlacePrediction>[];

        if (json['predictions'] != null) {
          for (var p in json['predictions'] as List) {
            predictions.add(PlacePrediction(
              placeId: p['place_id'] ?? '',
              mainText: p['structured_formatting']?['main_text'] ?? '',
              secondaryText: p['structured_formatting']?['secondary_text'] ?? '',
              fullText: p['description'] ?? '',
            ));
          }
        }

        // Cache the results
        _predictionCache[input] = predictions;
        print('✅ Found ${predictions.length} location predictions');
        return predictions;
      } else {
        print('❌ Places API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Places search error: $e');
      return [];
    }
  }

  /// Get detailed place information including coordinates from place ID
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId, String sessionToken) async {
    try {
      final String url =
          '$_baseUrl/details/json?place_id=$placeId&fields=geometry,formatted_address&key=$_apiKey&sessiontoken=$sessionToken';

      print('📍 Fetching details for place: $placeId');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'];

        if (result != null && result['geometry'] != null) {
          final location = result['geometry']['location'];
          return {
            'latitude': location['lat'] as double,
            'longitude': location['lng'] as double,
            'address': result['formatted_address'] as String,
          };
        }
      } else {
        print('❌ Place details API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Place details error: $e');
    }
    return null;
  }

  /// ✅ PHASE 5: Get directions between two locations for route polyline
  /// Returns list of LatLng points representing the route, plus distance/duration info
  static Future<Map<String, dynamic>?> getDirections(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    try {
      const String directionUrl = 'https://maps.googleapis.com/maps/api/directions/json';
      final String url =
          '$directionUrl?origin=$originLat,$originLng&destination=$destLat,$destLng&key=$_apiKey&mode=driving';

      print('🗺️ Fetching directions from ($originLat,$originLng) to ($destLat,$destLng)');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['routes'] != null && (json['routes'] as List).isNotEmpty) {
          final route = json['routes'][0];
          final legs = route['legs'][0];

          // Decode polyline from overview_polyline
          final encodedPolyline = route['overview_polyline']['points'] as String;
          final decodedPoints = _decodePolyline(encodedPolyline);

          return {
            'points': decodedPoints,
            'distance': legs['distance']['text'],
            'distanceValue': legs['distance']['value'], // in meters
            'duration': legs['duration']['text'],
            'durationValue': legs['duration']['value'], // in seconds
            'encodedPolyline': encodedPolyline,
          };
        }
      } else {
        print('❌ Directions API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Directions error: $e');
    }
    return null;
  }

  /// Decode polyline from Google Directions API
  /// Uses the standard Google polyline encoding algorithm
  static List<Map<String, double>> _decodePolyline(String encoded) {
    final List<Map<String, double>> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add({
        'latitude': lat / 1e5,
        'longitude': lng / 1e5,
      });
    }

    return points;
  }

  /// Clear prediction cache
  static void clearCache() {
    _predictionCache.clear();
    print('🧹 Places prediction cache cleared');
  }
}
