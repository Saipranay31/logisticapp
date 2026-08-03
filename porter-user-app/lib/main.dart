import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/theme_provider.dart';
import 'services/geocoding_service.dart';
import 'services/places_service.dart';
import 'services/api_service.dart';
import 'config/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/booking_flow_screen.dart';
import 'screens/tracking/tracking_screen.dart';
import 'screens/bill_confirmation_screen.dart';
import 'screens/payment_processing_screen.dart';
import 'screens/driver_rating_screen.dart';
import 'screens/driver_discovery_screen.dart';
import 'screens/delivery_completed_screen.dart';
import 'screens/support_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/map_picker_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';
import 'screens/account_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.navigatorKey = _navigatorKey;

  // Load .env before anything else
  await dotenv.load(fileName: '.env');

  // ✨ Initialize geocoding service with SQLite cache
  try {
    print('🗺️ Initializing geocoding cache...');
    await GeocodingService.initialize();
    print('✅ Geocoding service initialized');
  } catch (e) {
    print('⚠️ Geocoding initialization failed (non-critical): $e');
  }

  // ✨ Initialize Places service for location search
  try {
    print('🔍 Initializing Places service...');
    await PlacesService.initialize();
    print('✅ Places service initialized');
  } catch (e) {
    print('⚠️ Places initialization failed (non-critical): $e');
  }

  // ✨ CRITICAL FIX: Initialize Firebase for push notifications
  try {
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('⚠️ App will continue but FCM notifications will NOT work');
  }

  // ✨ CRITICAL FIX: Initialize Firebase messaging
  try {
    print('🔔 Setting up Firebase messaging...');
    final messaging = FirebaseMessaging.instance;
    // Request notification permissions
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('✅ Firebase messaging initialized with settings: ${settings.authorizationStatus}');
  } catch (e) {
    print('❌ Firebase messaging initialization failed: $e');
  }

  // 🔴 CRITICAL FIX: Request location permission on app startup
  // Needed for pickup location - shows current location or allows location input
  try {
    final locStatus = await Permission.location.request();
    if (locStatus.isDenied) {
      print('⚠️ Location permission DENIED - user will need to input location manually');
    } else if (locStatus.isGranted) {
      print('✅ Location permission GRANTED - user location available');
    }
  } catch (e) {
    print('⚠️ Could not request location permission: $e');
  }

  // 🔴 CRITICAL FIX: Request notification permission on app startup
  // Needed to notify user when driver accepts ride
  try {
    final notifStatus = await Permission.notification.request();
    if (notifStatus.isDenied) {
      print('⚠️ Notification permission DENIED - user will not see ride updates');
    } else if (notifStatus.isGranted) {
      print('✅ Notification permission GRANTED - user will receive ride notifications');
    }
  } catch (e) {
    print('⚠️ Could not request notification permission: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const PorterUserApp(),
    ),
  );
}

class PorterUserApp extends StatelessWidget {
  const PorterUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        // Initialize theme provider on first build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          themeProvider.initialize();
        });

        return MaterialApp(
          title: 'Porter',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/profile-setup': (_) => const ProfileSetupScreen(),
        '/home': (_) => const HomeScreen(),
        '/booking': (_) => const BookingScreen(),
        '/booking-flow': (_) => const BookingFlowScreen(),
        '/history': (_) => const HistoryScreen(),   // ← was broken, now fixed
        '/account': (_) => const AccountScreen(),   // ← add this line
        '/map-picker': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MapPickerScreen(
            title: args?['title'] ?? 'Select Location',
            initialLat: args?['initialLat'],
            initialLng: args?['initialLng'],
          );
        },
        '/driver-discovery': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverDiscoveryScreen(
            vehicleType: args?['vehicleType'] ?? 'BIKE',
            pickupLatitude: args?['pickupLatitude'] ?? 28.6139,
            pickupLongitude: args?['pickupLongitude'] ?? 77.2090,
            pickupAddress: args?['pickupAddress'] ?? 'Pickup Location',
            dropAddress: args?['dropAddress'] ?? 'Drop Location',
          );
        },
        '/tracking': (_) => const TrackingScreen(),
        '/bill-confirmation': (_) => const BillConfirmationScreen(),
        '/payment-processing': (_) => const PaymentProcessingScreen(),
        '/driver-rating': (_) => const DriverRatingScreen(),
        '/delivery-completed': (_) => const DeliveryCompletedScreen(),
        '/completed': (_) => const DeliveryCompletedScreen(),
        '/support': (_) => const SupportScreen(),
        '/notification-settings': (_) => const NotificationSettingsScreen(),
        '/emergency-contacts': (_) => const EmergencyContactsScreen(),
        '/chat': (_) => const ChatScreen(),
      },
    );
      },
    );
  }
}
