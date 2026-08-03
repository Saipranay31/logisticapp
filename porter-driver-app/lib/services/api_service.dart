import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Comprehensive API Service for Porter Backend
/// Handles all HTTP requests with error handling and token management
class ApiService {
  static String _token = '';
  static String _refreshToken = '';
  static GlobalKey<NavigatorState>? navigatorKey;
  // Guard: prevents multiple simultaneous login redirects from parallel 401s
  static bool _isLoggingOut = false;

  // ─── TOKEN MANAGEMENT ───
  static void setToken(String token, {String? refreshToken}) {
    _token = token;
    if (refreshToken != null) _refreshToken = refreshToken;
  }

  static String getToken() => _token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  // ✅ Helper to construct full image URLs from relative or legacy paths
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;

    final origin = AppConfig.baseUrl.replaceFirst(RegExp(r'/api$'), '');

    // New-style: /api/files/drivers/uuid.jpg
    if (imagePath.startsWith('/api/')) return '$origin$imagePath';

    // Legacy Windows filesystem paths — extract category/filename
    for (final cat in ['drivers', 'users', 'kyc-documents', 'kyc']) {
      final idx = imagePath.lastIndexOf('/$cat/');
      if (idx != -1) {
        return '$origin/api/files${imagePath.substring(idx)}';
      }
    }

    return '$origin/api$imagePath';
  }

  // Helper to handle API responses
  // autoLogout: set to false for background/fire-and-forget calls to avoid
  // kicking the user out when a non-critical call returns 401
  static Future<T> _handleResponse<T>(
    Future<http.Response> request,
    T Function(Map<String, dynamic>) parser, {
    bool autoLogout = true,
  }) async {
    try {
      final response = await request.timeout(
        Duration(seconds: AppConfig.apiTimeoutSeconds),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend returns { "success": true, "message": "...", "data": ... }
        if (body['success'] == true) {
          return parser(body);
        } else {
          throw Exception(body['message'] ?? 'API returned false success');
        }
      } else if (response.statusCode == 403) {
        // Token is valid but account is suspended — go to suspended screen
        // Do NOT clear token (it's still valid; admin may re-activate)
        print('🚫 403 from: ${response.request?.url}');
        if (autoLogout && !_isLoggingOut && navigatorKey?.currentState != null) {
          _isLoggingOut = true;
          navigatorKey!.currentState!.pushNamedAndRemoveUntil('/suspended', (_) => false);
          Future.delayed(const Duration(seconds: 3), () => _isLoggingOut = false);
        }
        throw Exception('Account suspended');
      } else if (response.statusCode == 401) {
        if (autoLogout) {
          if (!_isLoggingOut && navigatorKey?.currentState != null) {
            _token = '';
            _refreshToken = '';
            _isLoggingOut = true;
            navigatorKey!.currentState!.pushNamedAndRemoveUntil('/login', (_) => false);
            Future.delayed(const Duration(seconds: 3), () => _isLoggingOut = false);
          }
        }
        throw Exception('Session expired. Please sign in again.');
      } else {
        throw Exception(body['message'] ?? 'Error: ${response.statusCode}');
      }
    } catch (e) {
      if (AppConfig.enableDebugLogging) print('API Error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────
  // ─── AUTHENTICATION ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Send OTP to phone number
  static Future<Map<String, dynamic>> sendOtp(String phone, String role) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/otp/send'),
        headers: _headers,
        body: jsonEncode({'phone': phone, 'role': role}),
      ),
      (body) => {'success': true, 'message': body['message'] ?? 'OTP sent'},
    );
  }

  /// Verify OTP and get auth tokens
  static Future<AuthResponse> verifyOtp(
      String phone, String otp, String role, [String? fullName, File? profileImage]) async {
    fullName ??= 'Driver';

    if (profileImage == null) {
      // No image - use regular JSON request
      return _handleResponse(
        http.post(
          Uri.parse('${AppConfig.baseUrl}/auth/otp/verify'),
          headers: _headers,
          body: jsonEncode({
            'phone': phone,
            'otp': otp,
            'role': role,
            'fullName': fullName
          }),
        ),
        (body) => AuthResponse.fromJson(body['data'] ?? {}),
      );
    } else {
      // With image - use multipart request
      print('📤 Uploading profile image for driver: $phone');
      final uri = Uri.parse('${AppConfig.baseUrl}/auth/otp/verify');
      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['phone'] = phone;
      request.fields['otp'] = otp;
      request.fields['role'] = role;
      request.fields['fullName'] = fullName;

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          profileImage.path,
          filename: 'profile_${phone}.jpg',
        ),
      );

      // Add authorization header
      request.headers.addAll({'Authorization': 'Bearer $_token'});

      try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          throw Exception('Upload failed: ${response.statusCode}');
        }

        final jsonData = jsonDecode(response.body);
        print('✅ Profile image uploaded successfully');
        return AuthResponse.fromJson(jsonData['data'] ?? {});
      } catch (e) {
        print('❌ Image upload error: $e');
        throw Exception('Failed to upload profile image: $e');
      }
    }
  }

  /// Admin login with email and password
  static Future<AuthResponse> adminLogin(String email, String password) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/admin/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      ),
      (body) => AuthResponse.fromJson(body['data'] ?? {}),
    );
  }

  /// Refresh access token
  static Future<AuthResponse> refreshToken() async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/refresh'),
        headers: _headers,
        body: jsonEncode({'refreshToken': _refreshToken}),
      ),
      (body) => AuthResponse.fromJson(body['data'] ?? {}),
    );
  }

  // ─────────────────────────────────────────
  // ─── USER PROFILE ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Get user profile
  static Future<UserProfile> getUserProfile() async {
    return _handleResponse(
      http.get(Uri.parse('${AppConfig.baseUrl}/user/profile'), headers: _headers),
      (body) => UserProfile.fromJson(body['data']),
    );
  }

  /// Update user profile
  static Future<UserProfile> updateUserProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    final params = <String, String>{};
    if (fullName != null) params['fullName'] = fullName;
    if (avatarUrl != null) params['avatarUrl'] = avatarUrl;

    final uri = Uri.parse('${AppConfig.baseUrl}/user/profile')
        .replace(queryParameters: params.isEmpty ? null : params);

    return _handleResponse(
      http.put(uri, headers: _headers),
      (body) => UserProfile.fromJson(body['data']),
    );
  }

  // ─────────────────────────────────────────
  // ─── ADDRESS ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Get all user addresses
  static Future<List<UserAddress>> getAddresses() async {
    return _handleResponse(
      http.get(Uri.parse('${AppConfig.baseUrl}/user/addresses'), headers: _headers),
      (body) => List<UserAddress>.from(
          (body['data'] as List).map((x) => UserAddress.fromJson(x))),
    );
  }

  /// Add new address
  static Future<UserAddress> addAddress({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/user/addresses'),
        headers: _headers,
        body: jsonEncode({
          'label': label,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ),
      (body) => UserAddress.fromJson(body['data']),
    );
  }

  /// Delete address
  static Future<void> deleteAddress(String addressId) async {
    await _handleResponse(
      http.delete(
        Uri.parse('${AppConfig.baseUrl}/user/addresses/$addressId'),
        headers: _headers,
      ),
      (body) => null,
    );
  }

  // ─────────────────────────────────────────
  // ─── DRIVER PROFILE ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Get driver profile
  static Future<DriverProfile> getDriverProfile() async {
    return _handleResponse(
      http.get(Uri.parse('${AppConfig.baseUrl}/driver/profile'), headers: _headers),
      (body) => DriverProfile.fromJson(body['data']),
    );
  }

  /// Create driver profile
  static Future<DriverProfile> createDriverProfile(String licenseNumber) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/driver/profile')
        .replace(queryParameters: {'licenseNumber': licenseNumber});
    return _handleResponse(
      http.post(uri, headers: _headers),
      (body) => DriverProfile.fromJson(body['data']),
    );
  }

  /// Toggle online status
  static Future<DriverProfile> toggleOnlineStatus(
    bool online, {
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, String>{'online': online.toString()};
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();

    final uri = Uri.parse('${AppConfig.baseUrl}/driver/toggle-online')
        .replace(queryParameters: params);

    return _handleResponse(
      http.post(uri, headers: _headers),
      (body) => DriverProfile.fromJson(body['data']),
    );
  }

  /// Register vehicle
  static Future<Map<String, dynamic>> registerVehicle({
    required String vehicleType,
    required String vehicleNumber,
    String? vehicleModel,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/driver/vehicle'),
        headers: _headers,
        body: jsonEncode({
          'vehicleType': vehicleType,
          'vehicleNumber': vehicleNumber,
          'vehicleModel': vehicleModel ?? '',
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Upload KYC document
  static Future<Map<String, dynamic>> uploadDocument({
    required String documentType,
    required String documentUrl,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/driver/documents'),
        headers: _headers,
        body: jsonEncode({
          'documentType': documentType,
          'documentUrl': documentUrl,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Upload KYC document file (multipart)
  static Future<Map<String, dynamic>> uploadDocumentFile({
    required String driverProfileId,
    required String documentType,
    required File file,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/documents/upload'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $_token',
      });

      // Add form fields
      request.fields['driverProfileId'] = driverProfileId;
      request.fields['documentType'] = documentType;

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      // Send request
      final response = await request.send().timeout(
            Duration(seconds: AppConfig.apiTimeoutSeconds),
            onTimeout: () => throw Exception('Upload timeout'),
          );

      final responseBody = await response.stream.bytesToString();
      final body = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          return body['data'];
        } else {
          throw Exception(body['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception(body['message'] ?? 'Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Update driver profile with license number and optional profile picture
  static Future<Map<String, dynamic>> updateProfileWithLicense({
    required String licenseNumber,
    String? fullName,
    File? profilePictureFile,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${AppConfig.baseUrl}/driver/profile'),
      );

      // Add auth headers
      request.headers.addAll({
        'Authorization': 'Bearer $_token',
      });

      // Add form fields
      request.fields['licenseNumber'] = licenseNumber;

      // ✅ NEW: Add fullName if provided
      if (fullName != null && fullName.isNotEmpty) {
        request.fields['fullName'] = fullName;
        print('📝 Full name included in driver profile update: $fullName');
      }

      // Add profile picture file if provided
      if (profilePictureFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profilePicture', profilePictureFile.path),
        );
        print('📸 Profile picture included in update');
      }

      // Send request
      final response = await request.send().timeout(
            Duration(seconds: AppConfig.apiTimeoutSeconds),
            onTimeout: () => throw Exception('Upload timeout'),
          );

      final responseBody = await response.stream.bytesToString();
      final body = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          print('✅ Profile updated successfully with license: $licenseNumber, fullName: $fullName');
          return body['data'] ?? {};
        } else {
          throw Exception(body['message'] ?? 'Update failed');
        }
      } else {
        throw Exception(body['message'] ?? 'Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Profile update error: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Upload profile picture during KYC completion
  static Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/driver/profile'),
      );

      // Add auth headers
      request.headers.addAll({
        'Authorization': 'Bearer $_token',
      });

      // Add form fields (license number is required)
      request.fields['licenseNumber'] = 'PROFILE_UPDATE'; // Dummy value for picture update

      // Add profile picture file
      request.files.add(
        await http.MultipartFile.fromPath('profilePicture', imageFile.path),
      );

      // Send request
      final response = await request.send().timeout(
            Duration(seconds: AppConfig.apiTimeoutSeconds),
            onTimeout: () => throw Exception('Upload timeout'),
          );

      final responseBody = await response.stream.bytesToString();
      final body = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          print('✅ Profile picture uploaded successfully');
          return body['data'] ?? {};
        } else {
          throw Exception(body['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception(body['message'] ?? 'Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Profile picture upload error: $e');
      rethrow;
    }
  }

  /// Get driver documents
  static Future<List<Map<String, dynamic>>> getDocuments() async {
    return _handleResponse(
      http.get(Uri.parse('${AppConfig.baseUrl}/driver/documents'), headers: _headers),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Submit KYC for approval
  static Future<DriverProfile> submitKyc() async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/driver/kyc/submit'),
        headers: _headers,
      ),
      (body) => DriverProfile.fromJson(body['data']),
    );
  }

  /// Get driver earnings
  static Future<Map<String, dynamic>> getDriverEarnings({
    String period = 'daily',
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/driver/earnings')
        .replace(queryParameters: {'period': period});

    return _handleResponse(
      http.get(uri, headers: _headers),
      (body) => body['data'],
    );
  }

  // ─────────────────────────────────────────
  // ─── RIDE ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Create a new ride
  static Future<RideData> createRide({
    required String pickupAddress,
    required String dropAddress,
    required String vehicleType,
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropLatitude,
    required double dropLongitude,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides'),
        headers: _headers,
        body: jsonEncode({
          'pickupAddress': pickupAddress,
          'dropAddress': dropAddress,
          'vehicleType': vehicleType,
          'pickupLatitude': pickupLatitude,
          'pickupLongitude': pickupLongitude,
          'dropLatitude': dropLatitude,
          'dropLongitude': dropLongitude,
        }),
      ),
      (body) => RideData.fromJson(body['data']),
    );
  }

  /// Get ride details
  static Future<RideData> getRide(String rideId) async {
    return _handleResponse(
      http.get(Uri.parse('${AppConfig.baseUrl}/rides/$rideId'), headers: _headers),
      (body) => RideData.fromJson(body['data']),
    );
  }

  /// Accept ride (driver)
  static Future<RideData> acceptRide(String rideId) async {
    print('📤 ACCEPT RIDE: Sending POST /rides/$rideId/accept');
    try {
      final result = await _handleResponse(
        http.post(
          Uri.parse('${AppConfig.baseUrl}/rides/$rideId/accept'),
          headers: _headers,
        ),
        (body) => RideData.fromJson(body['data']),
      );
      print('✅ ACCEPT RIDE SUCCESS: rideId=$rideId, status=${result.status}, driverId=${result.driverId}');
      return result;
    } catch (e) {
      print('❌ ACCEPT RIDE FAILED: $e');
      rethrow;
    }
  }

  /// Mark driver arrived
  static Future<RideData> driverArrived(String rideId) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/arrive'),
        headers: _headers,
      ),
      (body) => RideData.fromJson(body['data']),
    );
  }

  /// Start ride with OTP verification
  static Future<RideData> startRide(String rideId, String otp) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/start')
            .replace(queryParameters: {'otp': otp}),
        headers: _headers,
      ),
      (body) => RideData.fromJson(body['data']),
    );
  }

  /// Complete ride
  static Future<RideData> completeRide(String rideId) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/complete'),
        headers: _headers,
      ),
      (body) => RideData.fromJson(body['data']),
    );
  }

  /// Cancel ride
  static Future<RideData> cancelRide(String rideId) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/cancel'),
        headers: _headers,
      ),
      (body) => RideData.fromJson(body['data']),
    );
  }

  /// Confirm cash payment received from user
  static Future<RideData> confirmCashPayment(String rideId) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/confirm-cash'),
        headers: _headers,
      ),
      (body) => RideData.fromJson(body['data']),
    );
  }

  /// Send chat message for a ride
  static Future<Map<String, dynamic>> sendChatMessage(String rideId, String message, String senderRole) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/chat'),
        headers: _headers,
        body: jsonEncode({'message': message, 'senderRole': senderRole}),
      ),
      (body) => body['data'] as Map<String, dynamic>,
    );
  }

  /// Get chat messages for a ride
  static Future<List<Map<String, dynamic>>> getChatMessages(String rideId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/chat'),
        headers: _headers,
      ),
      (body) => (body['data'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    );
  }

  /// Get driver's active ride (if any)
  static Future<RideData?> getDriverActiveRide() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/rides/driver/active'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['data'] != null) {
        return RideData.fromJson(body['data']);
      }
      return null;
    } catch (e) {
      print('⚠️ Failed to check driver active ride: $e');
      return null;
    }
  }

  /// Get user ride history
  static Future<List<RideData>> getUserRideHistory() async {
    return _handleResponse(
      http.get(Uri.parse('${AppConfig.baseUrl}/rides/user/history'), headers: _headers),
      (body) => List<RideData>.from(
          (body['data'] as List).map((x) => RideData.fromJson(x))),
    );
  }

  /// Get driver ride history
  static Future<List<RideData>> getDriverRideHistory() async {
    return _handleResponse(
      http.get(Uri.parse('${AppConfig.baseUrl}/rides/driver/history'), headers: _headers),
      (body) => List<RideData>.from(
          (body['data'] as List).map((x) => RideData.fromJson(x))),
    );
  }

  // ─────────────────────────────────────────
  // ─── FARE CONFIGURATION ───
  // ─────────────────────────────────────────

  static Map<String, dynamic>? _fareConfigCache;
  static DateTime? _fareConfigCacheTime;
  static const Duration _fareConfigCacheTTL = Duration(minutes: 5);

  /// Get fare configuration from backend
  /// Caches result for 5 minutes to minimize API calls
  static Future<Map<String, dynamic>> getFareConfig() async {
    try {
      // Return cached config if still valid
      if (_fareConfigCache != null && _fareConfigCacheTime != null) {
        if (DateTime.now().difference(_fareConfigCacheTime!).inMinutes < 5) {
          print('📦 Fare config from cache (${DateTime.now().difference(_fareConfigCacheTime!).inSeconds}s old)');
          return _fareConfigCache!;
        }
      }

      // Fetch from backend
      final config = await _handleResponse(
        http.get(Uri.parse('${AppConfig.baseUrl}/fares/config'), headers: _headers),
        (body) => Map<String, dynamic>.from(body['data']),
      );

      // Cache the result
      _fareConfigCache = config;
      _fareConfigCacheTime = DateTime.now();
      print('✅ Fare config fetched and cached: $config');

      return config;
    } catch (e) {
      print('❌ Error fetching fare config: $e');
      // Return fallback config if API fails
      return _getFallbackFareConfig();
    }
  }

  /// Fallback fare configuration when API is unavailable
  static Map<String, dynamic> _getFallbackFareConfig() {
    return {
      'baseFare': 50.0,
      'perKmRate': 12.0,
      'perMinRate': 2.0,
      'vehicleMultipliers': {
        'BIKE': 1.0,
        'AUTO': 1.5,
        'MINI_TRUCK': 2.5,
        'TRUCK': 4.0,
      },
      'currency': 'INR',
    };
  }

  // ─────────────────────────────────────────
  // ─── LOCATION TRACKING ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Update ride location
  static Future<void> updateRideLocation(
    String rideId, {
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    double? accuracy,
    double? altitude,
  }) async {
    await _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/location'),
        headers: _headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          if (speed != null) 'speed': speed,
          if (heading != null) 'heading': heading,
          if (accuracy != null) 'accuracy': accuracy,
          if (altitude != null) 'altitude': altitude,
        }),
      ),
      (body) => null,
    );
  }

  /// Get current ride location
  static Future<Map<String, dynamic>> getRideLocation(String rideId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/location'),
        headers: _headers,
      ),
      (body) => body['data'],
    );
  }

  /// Get ride waypoints
  static Future<List<Map<String, dynamic>>> getRideWaypoints(String rideId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/waypoints'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Get ETA
  static Future<Map<String, dynamic>> getRideEta(String rideId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/eta'),
        headers: _headers,
      ),
      (body) => body['data'],
    );
  }

  /// Send driver location update to backend
  static Future<void> sendDriverLocation({
    required String rideId,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    double? accuracy,
    double? altitude,
  }) async {
    await _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/location'),
        headers: _headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          if (speed != null) 'speed': speed,
          if (heading != null) 'heading': heading,
          if (accuracy != null) 'accuracy': accuracy,
          if (altitude != null) 'altitude': altitude,
        }),
      ),
      (body) => null,
    );
  }

  /// 🔴 CRITICAL FIX: Update driver location when online (not on a ride)
  /// This registers driver location in Redis for driver discovery
  static Future<void> updateDriverOnlineLocation({
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/location/update')
          .replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      await _handleResponse(
        http.post(uri, headers: _headers),
        (body) => null,
      );
      print('✅ Driver online location sent to Redis: ($latitude, $longitude)');
    } catch (e) {
      print('⚠️ Could not update online location: $e');
    }
  }

  // ─────────────────────────────────────────
  // ─── PAYMENT ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Create Razorpay order
  static Future<Map<String, dynamic>> createPaymentOrder(String rideId) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/payments/create-order'),
        headers: _headers,
        body: jsonEncode({'rideId': rideId}),
      ),
      (body) => body['data'],
    );
  }

  /// Verify payment
  static Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String rideId,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/payments/verify'),
        headers: _headers,
        body: jsonEncode({
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
          'rideId': rideId,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Get user payments
  static Future<List<Map<String, dynamic>>> getUserPayments() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/payments/user'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Get driver payments
  static Future<List<Map<String, dynamic>>> getDriverPayments() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/payments/driver'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  // ─────────────────────────────────────────
  // ─── RATING ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Rate a ride
  static Future<Map<String, dynamic>> rateRide(
    String rideId,
    int rating, {
    String? review,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/rate'),
        headers: _headers,
        body: jsonEncode({
          'rating': rating,
          if (review != null) 'review': review,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Driver rates the customer after ride completion.
  static Future<Map<String, dynamic>> rateUser(
    String rideId,
    int rating, {
    String? review,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/rate-user'),
        headers: _headers,
        body: jsonEncode({
          'rating': rating,
          if (review != null) 'review': review,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Get ride rating
  static Future<Map<String, dynamic>?> getRideRating(String rideId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/rating'),
        headers: _headers,
      ),
      (body) => body['data'],
    );
  }

  /// Get driver ratings
  static Future<Map<String, dynamic>> getDriverRatings(String driverId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/driver/$driverId/ratings'),
        headers: _headers,
      ),
      (body) => body['data'],
    );
  }

  /// Get driver reviews
  static Future<List<Map<String, dynamic>>> getDriverReviews(
    String driverId, {
    int limit = 5,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/driver/$driverId/reviews')
        .replace(queryParameters: {'limit': limit.toString()});

    return _handleResponse(
      http.get(uri, headers: _headers),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  // ─────────────────────────────────────────
  // ─── EMERGENCY ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Trigger SOS
  static Future<Map<String, dynamic>> triggerSOS({
    String? rideId,
    required double latitude,
    required double longitude,
    String description = 'Emergency SOS triggered',
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/emergency/sos'),
        headers: _headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'alertType': 'SOS',
          'description': description,
          if (rideId != null) 'rideId': rideId,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Get emergency contacts
  static Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/emergency/contacts'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Add emergency contact
  static Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/emergency/contacts'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'relationship': relationship,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Delete emergency contact
  static Future<void> deleteEmergencyContact(String contactId) async {
    await _handleResponse(
      http.delete(
        Uri.parse('${AppConfig.baseUrl}/emergency/contacts/$contactId'),
        headers: _headers,
      ),
      (body) => null,
    );
  }

  // ─────────────────────────────────────────
  // ─── DISPUTE ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Create dispute
  static Future<Map<String, dynamic>> createDispute({
    required String rideId,
    required String reason,
    String description = '',
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/dispute'),
        headers: _headers,
        body: jsonEncode({
          'reason': reason,
          'description': description,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Get dispute
  static Future<Map<String, dynamic>?> getDispute(String rideId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/rides/$rideId/dispute'),
        headers: _headers,
      ),
      (body) => body['data'],
    );
  }

  // ─────────────────────────────────────────
  // ─── SUPPORT TICKET ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Create support ticket
  static Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String description,
    required String category,
    String? rideId,
  }) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/support/tickets'),
        headers: _headers,
        body: jsonEncode({
          'subject': subject,
          'description': description,
          'category': category,
          if (rideId != null) 'rideId': rideId,
        }),
      ),
      (body) => body['data'],
    );
  }

  /// Get support tickets
  static Future<List<Map<String, dynamic>>> getSupportTickets() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/support/tickets'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Add ticket message
  static Future<Map<String, dynamic>> addTicketMessage(
    String ticketId,
    String message,
  ) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/support/tickets/$ticketId/messages'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      ),
      (body) => body['data'],
    );
  }

  /// Get ticket messages
  static Future<List<Map<String, dynamic>>> getTicketMessages(String ticketId) async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/support/tickets/$ticketId/messages'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  // ─────────────────────────────────────────
  // ─── NOTIFICATION ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Get notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/notifications'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    await _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/notifications/$notificationId/read'),
        headers: _headers,
      ),
      (body) => null,
    );
  }

  /// Get unread notification count
  static Future<int> getUnreadNotificationCount() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/notifications/unread-count'),
        headers: _headers,
      ),
      (body) => body['data']?.toInt() ?? 0,
    );
  }

  /// Register FCM device token
  static Future<void> registerDeviceToken(String token, {String platform = 'ANDROID'}) async {
    await _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/notifications/device-token'),
        headers: _headers,
        body: jsonEncode({'token': token, 'platform': platform}),
      ),
      (body) => null,
      autoLogout: false,
    );
  }

  /// Remove FCM device token
  static Future<void> removeDeviceToken(String token) async {
    await _handleResponse(
      http.delete(
        Uri.parse('${AppConfig.baseUrl}/notifications/device-token'),
        headers: _headers,
        body: jsonEncode({'token': token}),
      ),
      (body) => null,
    );
  }

  /// Get notification preferences
  static Future<Map<String, dynamic>> getNotificationPreferences() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/notification-preferences'),
        headers: _headers,
      ),
      (body) => body['data'],
    );
  }

  /// Update notification preferences
  static Future<Map<String, dynamic>> updateNotificationPreferences(
    Map<String, dynamic> preferences,
  ) async {
    return _handleResponse(
      http.put(
        Uri.parse('${AppConfig.baseUrl}/notification-preferences'),
        headers: _headers,
        body: jsonEncode(preferences),
      ),
      (body) => body['data'],
    );
  }

  // ─────────────────────────────────────────
  // ─── ADMIN ENDPOINTS ───
  // ─────────────────────────────────────────

  /// Get admin dashboard
  static Future<Map<String, dynamic>> getDashboard() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/dashboard'),
        headers: _headers,
      ),
      (body) => body['data'] ?? {},
    );
  }

  /// Get all drivers
  static Future<List<Map<String, dynamic>>> getAllDrivers() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/drivers'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Activate driver
  static Future<void> activateDriver(String driverId) async {
    await _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/admin/drivers/$driverId/activate'),
        headers: _headers,
      ),
      (body) => null,
    );
  }

  /// Suspend driver
  static Future<void> suspendDriver(String driverId) async {
    await _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/admin/drivers/$driverId/suspend'),
        headers: _headers,
      ),
      (body) => null,
    );
  }

  /// Get active rides
  static Future<List<Map<String, dynamic>>> getActiveRides() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/rides/active'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Get all users
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/users'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Get disputes
  static Future<List<Map<String, dynamic>>> getAllDisputes() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/disputes'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Get open disputes
  static Future<List<Map<String, dynamic>>> getOpenDisputes() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/disputes/open'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Resolve dispute
  static Future<Map<String, dynamic>> resolveDispute(String disputeId, {required bool approve, String notes = '', double? refundAmount}) async {
    return _handleResponse(
      http.post(
        Uri.parse('${AppConfig.baseUrl}/admin/disputes/$disputeId/resolve'),
        headers: _headers,
        body: jsonEncode({
          'approve': approve,
          'notes': notes,
          if (refundAmount != null) 'refundAmount': refundAmount,
        }),
      ),
      (body) => body['data'] ?? {},
    );
  }

  /// Get emergency alerts
  static Future<List<Map<String, dynamic>>> getEmergencyAlerts() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/emergency/alerts'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Get support tickets (admin)
  static Future<List<Map<String, dynamic>>> getAllTickets() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/support/tickets'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }

  /// Get open tickets (admin)
  static Future<List<Map<String, dynamic>>> getOpenTickets() async {
    return _handleResponse(
      http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/support/tickets/open'),
        headers: _headers,
      ),
      (body) => List<Map<String, dynamic>>.from(body['data'] as List),
    );
  }
}

// ─────────────────────────────────────────
// ─── DATA MODELS ───
// ─────────────────────────────────────────

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final String role;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'USER',
    );
  }
}

class UserProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }
}

class UserAddress {
  final String id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;

  UserAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}

class DriverProfile {
  final String id;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String licenseNumber;
  final String kycStatus;
  final bool isOnline;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final int totalRides;
  final double rating;
  final String? vehicleType;
  final String? vehicleNumber;
  final String? vehicleModel;

  DriverProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.avatarUrl,
    required this.licenseNumber,
    required this.kycStatus,
    required this.isOnline,
    required this.isActive,
    this.latitude,
    this.longitude,
    required this.totalRides,
    required this.rating,
    this.vehicleType,
    this.vehicleNumber,
    this.vehicleModel,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: (json['driverProfileId'] ?? json['id'] ?? '').toString(),
      fullName: json['fullName'],
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
      licenseNumber: json['licenseNumber'] ?? '',
      kycStatus: json['kycStatus'] ?? 'PENDING',
      isOnline: json['isOnline'] ?? json['online'] ?? false,
      isActive: json['isActive'] ?? json['active'] ?? true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      totalRides: json['totalRides'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      vehicleType: json['vehicleType'],
      vehicleNumber: json['vehicleNumber'],
      vehicleModel: json['vehicleModel'],
    );
  }
}

class RideData {
  final String id;
  final String status;
  final String pickupAddress;
  final String dropAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropLatitude;
  final double dropLongitude;
  final double estimatedFare;
  final double? actualFare;
  final double? estimatedDistance;
  final double? estimatedDuration;
  final DateTime createdAt;
  final String vehicleType;
  final String? driverId;
  final String? driverName;
  final String? userName;
  final String? userPhone;
  final double? userRating;
  final String? paymentMethod;
  final String? paymentStatus;
  final double? cancellationFee;

  RideData({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropLatitude,
    required this.dropLongitude,
    required this.estimatedFare,
    this.actualFare,
    this.estimatedDistance,
    this.estimatedDuration,
    required this.createdAt,
    required this.vehicleType,
    this.driverId,
    this.driverName,
    this.userName,
    this.userPhone,
    this.userRating,
    this.paymentMethod,
    this.paymentStatus,
    this.cancellationFee,
  });

  factory RideData.fromJson(Map<String, dynamic> json) {
    return RideData(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      pickupAddress: json['pickupAddress'] ?? '',
      dropAddress: json['dropAddress'] ?? '',
      pickupLatitude: (json['pickupLatitude'] ?? 12.9716).toDouble(),
      pickupLongitude: (json['pickupLongitude'] ?? 77.5946).toDouble(),
      dropLatitude: (json['dropLatitude'] ?? 12.9816).toDouble(),
      dropLongitude: (json['dropLongitude'] ?? 77.6046).toDouble(),
      estimatedFare: (json['estimatedFare'] ?? 0).toDouble(),
      actualFare: (json['actualFare'] as num?)?.toDouble(),
      estimatedDistance: (json['estimatedDistanceKm'] as num?)?.toDouble(),
      estimatedDuration: (json['estimatedDurationMin'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      vehicleType: json['vehicleType'] ?? '',
      driverId: json['driverId'],
      driverName: json['driverName'],
      userName: json['userName'],
      userPhone: json['userPhone'],
      userRating: (json['userRating'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod'],
      paymentStatus: json['paymentStatus'],
      cancellationFee: (json['cancellationFee'] as num?)?.toDouble(),
    );
  }
}
