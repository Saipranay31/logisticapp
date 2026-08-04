import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import './api_service.dart';

/// Firebase Notification Service
/// Handles FCM initialization, token registration, and notification handling
class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();

  factory FirebaseNotificationService() {
    return _instance;
  }

  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final StreamController<String> _notificationStreamController = StreamController<String>.broadcast();

  Stream<String> get notificationStream => _notificationStreamController.stream;

  /// Initialize Firebase (DEPRECATED - use Firebase.initializeApp() in main.dart instead)
  /// Kept for backward compatibility only

  /// Initialize notifications and request permissions
  Future<String?> initializeNotifications() async {
    try {
      // Request notification permissions
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      // Get FCM token
      final String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      // Setup message handlers
      await _setupMessageHandlers();

      return token;
    } catch (e) {
      print('Error initializing notifications: $e');
      return null;
    }
  }

  /// Setup message handlers for foreground and background messages
  Future<void> _setupMessageHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Message received in foreground:');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      // 🔴 FIX: Only call _handleNotification, don't add raw message ID to stream
      _handleNotification(message);
    });

    // Handle background messages (when app is closed or in background)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    // Handle notification when app is opened from terminated state
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotification(initialMessage);
    }
  }

  /// Handle notification
  void _handleNotification(RemoteMessage message) {
    final String? rideId = message.data['rideId'];
    final String? type = message.data['type'];
    final String? action = message.data['action'];

    print('🔔 Notification Type: $type, Action: $action, RideId: $rideId');

    // Handle different notification types
    if (type == 'RIDE_REQUEST') {
      // 🔴 CRITICAL FIX: Handle new ride requests from users
      print('📲 *** NEW RIDE REQUEST *** $rideId');
      final String? pickupAddress = message.data['pickupAddress'];
      final String? dropAddress = message.data['dropAddress'];
      final String? fare = message.data['fare'];
      final String? distance = message.data['distance'];
      print('📍 Pickup: $pickupAddress → Drop: $dropAddress');
      print('💰 Estimated Fare: ₹$fare | 📏 Distance: ${distance}km');

      // Emit ride request to stream with proper format
      if (rideId != null) {
        _notificationStreamController.add('RIDE_REQUEST:$rideId');
      }
    } else if (type == 'RIDE_ACCEPTED') {
      // Driver accepted the ride
      print('✅ Ride accepted by driver: $rideId');
    } else if (type == 'RIDE_ARRIVING') {
      // Driver is arriving
      print('🚗 Driver arriving: $rideId');
    } else if (type == 'RIDE_STARTED') {
      // Ride started
      print('▶️ Ride started: $rideId');
    } else if (type == 'RIDE_COMPLETED') {
      // Ride completed
      print('✔️ Ride completed: $rideId');
    } else if (type == 'PAYMENT_RECEIVED') {
      // Payment received
      print('💳 Payment received');
    } else if (type == 'EMERGENCY_ALERT') {
      // Emergency alert
      print('🚨 Emergency alert');
    } else {
      print('⚠️ Unknown notification type: $type');
    }
  }

  /// Background message handler (static because it runs in isolate)
  static Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }

  /// Register device token with backend
  Future<void> registerDeviceToken(String token, String userRole) async {
    try {
      print('🔔 Registering device token with backend: $token');
      await ApiService.registerDeviceToken(token, platform: 'ANDROID');
      print('✅ Device token registered successfully with backend');
    } catch (e) {
      print('❌ Error registering device token: $e');
    }
  }

  /// Unregister device token from backend
  Future<void> unregisterDeviceToken(String token) async {
    try {
      print('🔔 Unregistering device token from backend: $token');
      await ApiService.removeDeviceToken(token);
      print('✅ Device token unregistered successfully');
    } catch (e) {
      print('❌ Error unregistering device token: $e');
    }
  }

  /// Subscribe to topic (for group notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationStreamController.close();
  }
}
