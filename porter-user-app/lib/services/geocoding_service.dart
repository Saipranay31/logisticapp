import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config/app_config.dart';

/// Service for reverse geocoding coordinates to addresses
/// Uses Google Maps Geocoding API with SQLite caching
class GeocodingService {
  static Database? _database;
  static const String _tableName = 'geocode_cache';
  static const Duration _cacheTTL = Duration(hours: 24);

  /// Initialize the geocoding cache database
  static Future<void> initialize() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'porter_geocoding.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              address TEXT NOT NULL,
              cached_at INTEGER NOT NULL,
              UNIQUE(latitude, longitude)
            )
          ''');
        },
      );

      print('✅ Geocoding cache database initialized');
    } catch (e) {
      print('⚠️ Failed to initialize geocoding database: $e');
    }
  }

  /// Reverse geocode coordinates to get human-readable address
  /// Returns cached result if available, otherwise fetches from Google Maps API
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // Check cache first
      final cachedAddress = await _getFromCache(latitude, longitude);
      if (cachedAddress != null) {
        print('📦 Address from cache: $cachedAddress');
        return cachedAddress;
      }

      // Try Google Maps API
      final address = await _geocodeFromGoogleMaps(latitude, longitude);

      // Cache the result
      if (address != null) {
        await _saveToCache(latitude, longitude, address);
        print('✅ Address from Google Maps (cached): $address');
        return address;
      }

      // Fallback to coordinate format
      final fallback = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
      await _saveToCache(latitude, longitude, fallback);
      print('⚠️ Address format (fallback): $fallback');
      return fallback;
    } catch (e) {
      print('❌ Error geocoding: $e');
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }

  /// Get address from cache if it exists and hasn't expired
  static Future<String?> _getFromCache(double latitude, double longitude) async {
    try {
      if (_database == null) return null;

      final results = await _database!.query(
        _tableName,
        where: 'latitude = ? AND longitude = ?',
        whereArgs: [latitude, longitude],
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int);
      final age = DateTime.now().difference(cachedAt);

      // Check if cache has expired (24 hours)
      if (age > _cacheTTL) {
        // Delete expired entry
        await _database!.delete(
          _tableName,
          where: 'latitude = ? AND longitude = ?',
          whereArgs: [latitude, longitude],
        );
        return null;
      }

      return row['address'] as String;
    } catch (e) {
      print('⚠️ Error querying geocode cache: $e');
      return null;
    }
  }

  /// Save address to cache
  static Future<void> _saveToCache(double latitude, double longitude, String address) async {
    try {
      if (_database == null) return;

      await _database!.insert(
        _tableName,
        {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('⚠️ Error saving to geocode cache: $e');
    }
  }

  /// Reverse geocode using Google Maps Geocoding API
  /// Requires Google Maps API key in AppConfig
  static Future<String?> _geocodeFromGoogleMaps(
    double latitude,
    double longitude,
  ) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=${AppConfig.googleMapsApiKey}';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Geocoding API timeout'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        if (json['status'] == 'OK' && json['results'] is List) {
          final results = json['results'] as List;
          if (results.isNotEmpty) {
            final firstResult = results[0] as Map<String, dynamic>;
            final formattedAddress = firstResult['formatted_address'] as String?;
            return formattedAddress;
          }
        }
      }

      print('⚠️ Google Maps API returned status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('⚠️ Google Maps API error: $e');
      return null;
    }
  }

  /// Clear all geocoding cache (for testing or manual refresh)
  static Future<void> clearCache() async {
    try {
      if (_database == null) return;
      await _database!.delete(_tableName);
      print('✅ Geocoding cache cleared');
    } catch (e) {
      print('⚠️ Error clearing cache: $e');
    }
  }

  /// Close the database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
