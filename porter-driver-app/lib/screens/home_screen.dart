import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'ride_request_modal.dart';
import '../screens/home_tab_screen.dart';
import '../screens/earnings_tab_screen.dart';
import '../screens/trips_tab_screen.dart';
import '../screens/performance_tab_screen.dart';
import '../screens/profile_tab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _navIdx = 0;
  bool _isOnline = false;
  StreamSubscription<String>? _notificationSubscription;

  static const bg = Color(0xFF0A0E21);

  // ─── LIFECYCLE ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 👈 Register lifecycle observer
    _loadOnlineStatus();
    _subscribeToRideNotifications();
    _checkActiveRide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 👈 Always remove observer
    _notificationSubscription?.cancel();
    super.dispose();
  }

  /// Called automatically by Flutter when app lifecycle changes:
  /// resumed  → app comes back to foreground (from recent apps, lock screen, etc.)
  /// paused   → app goes to background
  /// detached → app process killed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('📱 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;

      case AppLifecycleState.paused:
        // App went to background — don't stop tracking here.
        // LocationService continues running so Redis stays updated.
        print('📱 App paused — location tracking continues in background');
        break;

      case AppLifecycleState.detached:
        print('📱 App detached');
        break;

      default:
        break;
    }
  }

  /// Called when app returns to foreground.
  /// Re-validates online status from backend and restarts location tracking
  /// if the driver is still marked online — covers the case where tracking
  /// silently died while in the background or recent apps tray.
  Future<void> _onAppResumed() async {
    print('🔄 App resumed — re-checking online status...');
    // Read userId before any awaits (context cannot be used after async gap safely)
    final String? myUserId = mounted
        ? Provider.of<AuthProvider>(context, listen: false).userId
        : null;
    try {
      final profile = await ApiService.getDriverProfile();
      final isOnlineFromBackend = profile.isOnline;

      print('📊 Resume check: local=$_isOnline, backend=$isOnlineFromBackend');

      if (mounted) {
        setState(() => _isOnline = isOnlineFromBackend);
      }

      if (isOnlineFromBackend) {
        // Driver is still online on backend — push a fresh location to Redis
        // immediately, then restart continuous tracking stream.
        try {
          final position = await LocationService().getCurrentLocation();
          if (position != null) {
            await ApiService.toggleOnlineStatus(
              true,
              latitude: position.latitude,
              longitude: position.longitude,
            );
            print('✅ Pushed fresh location to Redis on resume: '
                '(${position.latitude}, ${position.longitude})');
          }
        } catch (e) {
          print('⚠️ Could not get location on resume: $e');
        }

        await LocationService().startTracking('ONLINE', driverId: myUserId);
        print('✅ Location tracking restarted after resume');
      }
    } catch (e) {
      print('❌ Error during app resume reinit: $e');
    }
  }

  // ─── ACTIVE RIDE CHECK ───────────────────────────────────────────────────────

  Future<void> _checkActiveRide() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated || authProvider.userId == null) {
        print('⚠️ Driver: Not authenticated, skipping active ride check');
        return;
      }

      final activeRide = await ApiService.getDriverActiveRide();
      if (activeRide != null && mounted) {
        final status = activeRide.status;
        print('🔄 Driver: Found active ride: ${activeRide.id}, status: $status');

        if (status == 'ASSIGNED' ||
            status == 'ARRIVED' ||
            status == 'IN_PROGRESS' ||
            status == 'COMPLETED') {
          final rideProvider =
              Provider.of<RideProvider>(context, listen: false);
          rideProvider.updateCurrentRide({
            'id': activeRide.id,
            'status': activeRide.status,
            'pickupAddress': activeRide.pickupAddress,
            'dropAddress': activeRide.dropAddress,
            'estimatedFare': activeRide.estimatedFare,
            'actualFare': activeRide.actualFare,
            'vehicleType': activeRide.vehicleType,
            'driverId': activeRide.driverId,
            'driverName': activeRide.driverName,
            'pickupLatitude': activeRide.pickupLatitude,
            'pickupLongitude': activeRide.pickupLongitude,
            'dropLatitude': activeRide.dropLatitude,
            'dropLongitude': activeRide.dropLongitude,
            'userName': activeRide.userName,
            'userPhone': activeRide.userPhone,
            'userRating': activeRide.userRating,
            'paymentMethod': activeRide.paymentMethod,
          });
          Navigator.pushNamed(context, '/active-delivery');
        }
      }
    } catch (e) {
      print('⚠️ Driver: Failed to check active ride: $e');
    }
  }

  // ─── NOTIFICATIONS ───────────────────────────────────────────────────────────

  void _subscribeToRideNotifications() {
    try {
      _notificationSubscription =
          FirebaseNotificationService().notificationStream.listen(
        (notification) {
          print('🔔 Received notification: $notification');
          if (mounted && notification.contains('RIDE_REQUEST')) {
            final parts = notification.split(':');
            if (parts.length == 2) {
              _fetchAndShowRideRequest(parts[1]);
            }
          }
        },
        onError: (error) => print('❌ Notification stream error: $error'),
        onDone: () => print('⚠️ Notification stream closed'),
      );
    } catch (e) {
      print('❌ Error subscribing to notifications: $e');
    }
  }

  Future<void> _fetchAndShowRideRequest(String rideId) async {
    try {
      final ride = await ApiService.getRide(rideId);
      if (!mounted) return;

      double? driverLat, driverLng;
      try {
        final position = await LocationService().getCurrentLocation();
        if (position != null) {
          driverLat = position.latitude;
          driverLng = position.longitude;
        }
      } catch (e) {
        print('⚠️ Could not get driver location: $e');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => RideRequestModal(
          rideId: ride.id,
          pickupAddress: ride.pickupAddress,
          dropAddress: ride.dropAddress,
          pickupLatitude: ride.pickupLatitude,
          pickupLongitude: ride.pickupLongitude,
          dropLatitude: ride.dropLatitude,
          dropLongitude: ride.dropLongitude,
          estimatedFare: ride.estimatedFare ?? 0,
          estimatedDistance: ride.estimatedDistance ?? 5.0,
          estimatedDurationMin: ride.estimatedDuration?.toInt() ?? 15,
          driverLatitude: driverLat,
          driverLongitude: driverLng,
        ),
      );
    } catch (e) {
      print('❌ Error fetching ride request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ride request: $e')),
        );
      }
    }
  }

  // ─── ONLINE STATUS ───────────────────────────────────────────────────────────

  Future<void> _loadOnlineStatus() async {
    try {
      final p = await ApiService.getDriverProfile();
      if (mounted) setState(() => _isOnline = p.isOnline);
    } catch (_) {}
  }

  Future<void> _toggleOnline(bool val) async {
    setState(() => _isOnline = val);
    try {
      double? lat, lng;
      if (val) {
        try {
          final position = await LocationService().getCurrentLocation();
          if (position != null) {
            lat = position.latitude;
            lng = position.longitude;
            print('📍 Got driver location for toggle: ($lat, $lng)');
          }
        } catch (e) {
          print('⚠️ Could not get location for toggle: $e');
        }
      }

      await ApiService.toggleOnlineStatus(val, latitude: lat, longitude: lng);

      if (val) {
        print('📍 Driver going ONLINE - starting location tracking');
        final toggleUserId =
            Provider.of<AuthProvider>(context, listen: false).userId;
        await LocationService().startTracking('ONLINE', driverId: toggleUserId);
      } else {
        print('📍 Driver going OFFLINE - stopping location tracking');
        LocationService().stopTracking();
      }
    } catch (e) {
      setState(() => _isOnline = !val);
      print('❌ Error toggling online status: $e');
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: IndexedStack(
        index: _navIdx,
        children: [
          HomeTabScreen(isOnline: _isOnline, onToggle: _toggleOnline),
          const EarningsTabScreen(),
          const TripsTabScreen(),
          const ProfileTabScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIdx,
        onTap: (i) => setState(() => _navIdx = i),
      ),
    );
  }
}