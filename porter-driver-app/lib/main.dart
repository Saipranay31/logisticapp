import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/active_delivery_screen.dart';
import 'screens/kyc_screen.dart';
import 'screens/support_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/suspended_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.navigatorKey = _navigatorKey;

  // Load .env before anything else
  await dotenv.load(fileName: '.env');

  // ✨ FIX #1: Initialize Firebase for push notifications
  try {
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('⚠️ App will continue but FCM notifications will NOT work');
  }

  // ✨ FIX #1: Initialize Firebase notifications and request permissions
  try {
    print('🔔 Setting up Firebase notifications...');
    final firebaseService = FirebaseNotificationService();
    final fcmToken = await firebaseService.initializeNotifications();
    if (fcmToken != null) {
      print('✅ Firebase notifications initialized');
      print('✅ FCM Token obtained: ${fcmToken.substring(0, 20)}...');
    } else {
      print('⚠️ FCM Token is NULL - notifications may not work!');
    }
  } catch (e) {
    print('❌ Firebase notifications initialization failed: $e');
  }

  // 🔴 CRITICAL FIX: Request location permission on app startup
  // Driver location MUST be tracked to show in user's driver discovery
  try {
    final locStatus = await Permission.location.request();
    if (locStatus.isDenied) {
      print('⚠️ Location permission DENIED - driver location will not be tracked');
    } else if (locStatus.isGranted) {
      print('✅ Location permission GRANTED - driver location tracking active');
    }
  } catch (e) {
    print('⚠️ Could not request location permission: $e');
  }

  // 🔴 CRITICAL FIX: Request notification permission on app startup
  try {
    final notifStatus = await Permission.notification.request();
    if (notifStatus.isDenied) {
      print('⚠️ Notification permission DENIED - driver will not receive ride requests');
    } else if (notifStatus.isGranted) {
      print('✅ Notification permission GRANTED - driver will receive ride requests');
    }
  } catch (e) {
    print('⚠️ Could not request notification permission: $e');
  }

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => RideProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: const PorterDriverApp(),
  ));
}

class PorterDriverApp extends StatelessWidget {
  const PorterDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        // Initialize theme provider on first build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          themeProvider.initialize();
        });

        return MaterialApp(
          title: 'Porter Driver',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          routes: {
            '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const HomeScreen(),
            '/kyc': (_) => const KycScreen(),
            '/suspended': (_) => const SuspendedScreen(),
            '/active-delivery': (_) => const ActiveDeliveryScreen(),
            '/trip-request': (_) => const ActiveDeliveryScreen(),
            '/support': (_) => const SupportScreen(),
            '/notification-settings': (_) => const NotificationSettingsScreen(),
            '/driver-chat': (_) => const DriverChatScreen(),
          },
        );
      },
    );
  }
}


