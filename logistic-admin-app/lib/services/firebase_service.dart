import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../config/app_config.dart';

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

  /// Initialize Firebase
  /// Call this once in main() before running the app
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey.isNotEmpty ? AppConfig.firebaseApiKey : 'AIzaSyDummyKey', // Loaded from .env
          appId: '1:1234567890:android:dummyappid',
          messagingSenderId: '1234567890',
          projectId: AppConfig.firebaseProjectId,
        ),
      );
      print('Firebase initialized successfully');
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

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

      _notificationStreamController.add(message.messageId ?? '');
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

    print('Notification Type: $type, Action: $action');

    // Handle different notification types
    if (type == 'RIDE_ACCEPTED') {
      // Driver accepted the ride
      print('Ride accepted by driver: $rideId');
    } else if (type == 'RIDE_ARRIVING') {
      // Driver is arriving
      print('Driver arriving: $rideId');
    } else if (type == 'RIDE_STARTED') {
      // Ride started
      print('Ride started: $rideId');
    } else if (type == 'RIDE_COMPLETED') {
      // Ride completed
      print('Ride completed: $rideId');
    } else if (type == 'PAYMENT_RECEIVED') {
      // Payment received
      print('Payment received');
    } else if (type == 'EMERGENCY_ALERT') {
      // Emergency alert
      print('Emergency alert');
    }
  }

  /// Background message handler (static because it runs in isolate)
  static Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }

  /// Register device token with backend
  Future<void> registerDeviceToken(String token, String userRole) async {
    print('Registering device token with backend: $token');
    // Call API service to register token
    // await ApiService.registerDeviceToken(token, platform: 'ANDROID');
  }

  /// Unregister device token from backend
  Future<void> unregisterDeviceToken(String token) async {
    print('Unregistering device token from backend: $token');
    // Call API service to unregister token
    // await ApiService.removeDeviceToken(token);
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
