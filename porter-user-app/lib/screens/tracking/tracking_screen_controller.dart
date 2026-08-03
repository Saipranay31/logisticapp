import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../services/places_service.dart';
import '../../models/cached_ride_data.dart';
import '../../screens/home_screen.dart'; // for TrackingRouter
import 'dead_reckoning_engine.dart';
import 'polyline_manager.dart';
import 'tracking_marker_icons.dart';
import 'tracking_tokens.dart';

// ═══════════════════════════════════════════════════════════
//  TRACKING SCREEN CONTROLLER MIXIN
//  Contains all business logic: WS, DR, polyline, camera,
//  markers, status/fare handling.
//  Mix this into _TrackingScreenState.
// ═══════════════════════════════════════════════════════════

mixin TrackingScreenController<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  // ── Static state (survives State recreation) ─────────────
  static String? activeRideId;
  static double driverLat = 12.9716;
  static double driverLng = 77.5946;
  static bool driverLocationInitialized = false;
  static double driverBearing = 0.0;

  static void cleanupStatic() {
    activeRideId = null;
    driverLat = 12.9716;
    driverLng = 77.5946;
    driverLocationInitialized = false;
    driverBearing = 0.0;
    CachedRideData.clear();
  }

  // ── Map ───────────────────────────────────────────────────
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool mapLoaded = false;

  // ── Icons ─────────────────────────────────────────────────
  BitmapDescriptor? vehicleIcon;
  BitmapDescriptor? pickupIcon;
  BitmapDescriptor? dropIcon;

  // ── Smooth marker animation ───────────────────────────────
  late AnimationController markerAnim;
  Animation<double>? latTween;
  Animation<double>? lngTween;

  // ── Dead reckoning ────────────────────────────────────────
  late DeadReckoningEngine dr;
  Timer? drTimer;

  // ── Polyline manager ──────────────────────────────────────
  final pm = PolylineManager();
  String? activePhaseName;
  DateTime? lastPolylineFetch;
  bool polylineFetchInFlight = false;
  static const polylineThrottle = Duration(seconds: 10);

  // ── WebSocket reconnect ───────────────────────────────────
  Timer? wsReconnectTimer;
  int wsReconnectAttempts = 0;
  bool wsConnected = false;

  // ── Camera ────────────────────────────────────────────────
  bool is3DMode = false;

  // ── Misc ──────────────────────────────────────────────────
  double eta = 18.0;
  DateTime? lastLocationUpdate;
  double currentFare = 0.0;
  int otpTimeRemaining = 300;
  Timer? otpCountdownTimer;
  CachedRideData? cachedRideData;

  // ── Searching state (cycling radius expansion) ────────────
  double searchRadiusKm = 5.0;
  int searchTimeRemaining = 600; // seconds (10 min)
  int searchCycle = 1;
  int searchRing = 1;
  Timer? _searchCountdownTimer;

  // ── Sheet animation ───────────────────────────────────────
  late AnimationController sheetAnim;

  // ═══════════════════════════════════════════════════════
  //  INIT HELPERS  (call from initState)
  // ═══════════════════════════════════════════════════════

  void controllerInit() {
    dr = DeadReckoningEngine(lat: driverLat, lng: driverLng);

    markerAnim = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addListener(onMarkerAnimTick);

    sheetAnim = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    final ride = Provider.of<RideProvider>(context, listen: false).currentRide;

    if (ride != null && !driverLocationInitialized) {
      final dLat = (ride['driverLatitude'] as num?)?.toDouble();
      final dLng = (ride['driverLongitude'] as num?)?.toDouble();
      final pLat = (ride['pickupLatitude'] as num?)?.toDouble() ?? 0;
      if (dLat != null &&
          dLng != null &&
          dLat != 0 &&
          (dLat - pLat).abs() < 1.0) {
        driverLat = dLat;
        driverLng = dLng;
        dr = DeadReckoningEngine(lat: dLat, lng: dLng);
        driverLocationInitialized = true;
      }
    }
CachedRideData.load().then((saved) {
    if (saved != null && mounted) {
      cachedRideData = saved;
      debugPrint('✅ CachedRideData restored: ${saved.driverName}, img=${saved.driverImage}');
      // Seed location if WS hasn't fired yet
      if (!driverLocationInitialized &&
          saved.currentLat != null &&
          saved.currentLng != null) {
        driverLat = saved.currentLat!;
        driverLng = saved.currentLng!;
        dr = DeadReckoningEngine(lat: driverLat, lng: driverLng);
        driverLocationInitialized = true;
      }
      setState(() => rebuildMarkers());
    }
  });

    _loadIcons(ride?['vehicleType']?.toString());

    if (ride != null && ride['status'] == 'ARRIVED') {
      final otp = ride['pickupOtp']?.toString();
      otp != null && otp.isNotEmpty
          ? startOtpCountdown(otp)
          : fetchOtpFromApi(ride['id']?.toString());
    }

    if (ride != null) fetchLatestRideData(ride['id']?.toString());

    final rideId = ride?['id']?.toString();
    if (rideId != null && activeRideId != rideId) initTracking();
  }

  void controllerDispose() {
    markerAnim
      ..removeListener(onMarkerAnimTick)
      ..dispose();
    sheetAnim.dispose();
    drTimer?.cancel();
    wsReconnectTimer?.cancel();
    otpCountdownTimer?.cancel();
    _searchCountdownTimer?.cancel();
    TrackingRouter.close();
    mapController?.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  ICON LOADING
  // ═══════════════════════════════════════════════════════

  Future<void> _loadIcons(String? vehicleType) async {
    vehicleIcon = await buildVehicleIcon(vehicleType);
    if (mounted) setState(() => rebuildMarkers());

    pickupIcon = await buildPickupIcon();
    if (mounted) setState(() => rebuildMarkers());

    dropIcon = await buildDropIcon();
    if (mounted) setState(() => rebuildMarkers());
  }

  // ═══════════════════════════════════════════════════════
  //  WEBSOCKET + RECONNECT
  // ═══════════════════════════════════════════════════════

  Future<void> initTracking() async {
    final ride =
        Provider.of<RideProvider>(context, listen: false).currentRide;
    if (ride == null) return;
    activeRideId = ride['id'].toString();
    await connectWs(activeRideId!, ride['userId']?.toString() ?? '');
  }

  Future<void> connectWs(String rideId, String userId) async {
    if (wsConnected && WebSocketService.isConnected) {
      debugPrint('⚡ WS already connected for ride $rideId — skipping');
      return;
    }
    try {
      await WebSocketService.connect();
      await WebSocketService.subscribeToRideLocation(rideId, onLocationUpdate);
      if (userId.isNotEmpty) {
        await WebSocketService.subscribeToRideStatus(userId, onStatusUpdate);
      }
      await WebSocketService.subscribeToRideFare(rideId, onFareUpdate);
      setState(() => wsConnected = true);
      wsReconnectAttempts = 0;
      wsReconnectTimer?.cancel();
      startDeadReckoning();
      debugPrint('✅ WebSocket connected');
    } catch (e) {
      setState(() => wsConnected = false);
      debugPrint('❌ WS failed: $e');
      scheduleReconnect(rideId, userId);
    }
  }

  void scheduleReconnect(String rideId, String userId) {
    wsReconnectTimer?.cancel();
    wsReconnectAttempts++;
    final delaySec =
        math.min(math.pow(2, wsReconnectAttempts).toInt(), 30);
    debugPrint(
        '🔄 Reconnect in ${delaySec}s (attempt $wsReconnectAttempts)');
    wsReconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (mounted) connectWs(rideId, userId);
    });
  }

  // ═══════════════════════════════════════════════════════
  //  DEAD RECKONING LOOP — 100ms tick
  // ═══════════════════════════════════════════════════════

  void startDeadReckoning() {
    drTimer?.cancel();
    drTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !dr.active) return;
      final predicted = dr.predict();
      if (haversineMetres(driverLat, driverLng, predicted.latitude,
              predicted.longitude) <
          1.0) return;
      applyDriverPosition(predicted.latitude, predicted.longitude,
          bearing: dr.bearing, isDR: true);
    });
  }

  // ═══════════════════════════════════════════════════════
  //  LOCATION UPDATE
  // ═══════════════════════════════════════════════════════

  void onLocationUpdate(Map<String, dynamic> loc) {
    if (!mounted) return;
    final newLat = (loc['latitude'] as num?)?.toDouble() ?? driverLat;
    final newLng = (loc['longitude'] as num?)?.toDouble() ?? driverLng;
if (driverLocationInitialized) {
    final jumpMetres = haversineMetres(driverLat, driverLng, newLat, newLng);
    if (jumpMetres > 500) {
      debugPrint('🚫 Rejected GPS jump of ${jumpMetres.toStringAsFixed(0)}m '
          '($driverLat,$driverLng) → ($newLat,$newLng)');
      return;
    }
  }
    dr.updateFix(newLat, newLng);
    lastLocationUpdate = DateTime.now();

    if (!driverLocationInitialized) {
      driverLat = newLat;
      driverLng = newLng;
      driverLocationInitialized = true;
      cachedRideData?.updateLocation(newLat, newLng);
      setState(() => rebuildMarkers());
      final ride =
          Provider.of<RideProvider>(context, listen: false).currentRide;
      if (ride != null) {
        final pLat = (ride['pickupLatitude'] as num?)?.toDouble();
        final pLng = (ride['pickupLongitude'] as num?)?.toDouble();
        if (pLat != null && pLng != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              fitBounds([LatLng(newLat, newLng), LatLng(pLat, pLng)]));
        }
      }
      return;
    }

    if (haversineMetres(driverLat, driverLng, newLat, newLng) < 5.0) return;

    applyDriverPosition(newLat, newLng,
        bearing: dr.bearing, isDR: false);

    final rp = Provider.of<RideProvider>(context, listen: false);
    if (rp.currentRide != null) {
      rp.updateCurrentRide({
        ...rp.currentRide!,
        'driverLatitude': newLat,
        'driverLongitude': newLng
      });
    }

    final ride = rp.currentRide;
    if (ride != null) maybeRefreshPolyline(ride['status'], ride);

    if (loc['estimatedEta'] != null) {
      setState(() => eta = (loc['estimatedEta'] as num).toDouble());
    }
  }

  // ═══════════════════════════════════════════════════════
  //  APPLY DRIVER POSITION
  // ═══════════════════════════════════════════════════════

  void applyDriverPosition(double newLat, double newLng,
      {double bearing = 0, bool isDR = false}) {
    final prevLat = driverLat;
    final prevLng = driverLng;

    driverLat = newLat;
    driverLng = newLng;
    driverBearing = bearing;
    cachedRideData?.updateLocation(newLat, newLng);

    setState(() => rebuildMarkers());
    animateMarker(prevLat, prevLng, newLat, newLng);

    if (pm.hasRoute) {
      final remaining = pm.trim(LatLng(newLat, newLng));
      if (remaining.length >= 2) {
        setState(() => polylines = {buildPolyline(remaining)});
      }
    }

    final ride =
        Provider.of<RideProvider>(context, listen: false).currentRide;
    if (!isDR &&
        ride?['status'] == 'IN_PROGRESS' &&
        mapLoaded &&
        mapController != null) {
      follow3D(newLat, newLng, bearing);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  MARKER ANIMATION
  // ═══════════════════════════════════════════════════════

  void onMarkerAnimTick() {
    if (latTween == null || lngTween == null || !mounted) return;
    final animLat = latTween!.value;
    final animLng = lngTween!.value;

    final updated = Set<Marker>.from(markers);
    final driver = updated.firstWhere(
      (m) => m.markerId.value == 'driver',
      orElse: () => Marker(markerId: const MarkerId('__none__')),
    );
    if (driver.markerId.value != '__none__') {
      updated.removeWhere((m) => m.markerId.value == 'driver');
      updated.add(driver.copyWith(
        positionParam: LatLng(animLat, animLng),
        rotationParam: driverBearing,
      ));
      setState(() => markers = updated);
    }
  }

  void animateMarker(
      double fLat, double fLng, double tLat, double tLng) {
    markerAnim.stop();
    markerAnim.reset();
    latTween = Tween<double>(begin: fLat, end: tLat).animate(
        CurvedAnimation(parent: markerAnim, curve: Curves.easeOutCubic));
    lngTween = Tween<double>(begin: fLng, end: tLng).animate(
        CurvedAnimation(parent: markerAnim, curve: Curves.easeOutCubic));
    markerAnim.forward();
  }

  // ═══════════════════════════════════════════════════════
  //  3D CAMERA
  // ═══════════════════════════════════════════════════════

  void follow3D(double lat, double lng, double bearing) {
    mapController!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(lat, lng),
          zoom: 17.5,
          tilt: 55,
          bearing: bearing),
    ));
  }

  void resetTo2D(List<LatLng> points) {
    is3DMode = false;
    mapController?.animateCamera(CameraUpdate.newCameraPosition(
      const CameraPosition(
          target: LatLng(0, 0), tilt: 0, bearing: 0, zoom: 5),
    ));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => fitBounds(points));
  }

  // ═══════════════════════════════════════════════════════
  //  POLYLINE
  // ═══════════════════════════════════════════════════════

  void maybeRefreshPolyline(String? status, Map<String, dynamic> ride) {
    if (status == null ||
        status == 'SEARCHING' ||
        status == 'COMPLETED') return;

    final pLat = (ride['pickupLatitude'] as num?)?.toDouble();
    final pLng = (ride['pickupLongitude'] as num?)?.toDouble();
    final dLat = (ride['dropLatitude'] as num?)?.toDouble();
    final dLng = (ride['dropLongitude'] as num?)?.toDouble();

    String phase;
    double fLat, fLng, tLat, tLng;
    switch (status) {
      case 'ASSIGNED':
        phase = 'driver_to_pickup';
        fLat = driverLat;
        fLng = driverLng;
        tLat = pLat ?? driverLat;
        tLng = pLng ?? driverLng;
      case 'ARRIVED':
        phase = 'pickup_to_drop_preview';
        fLat = pLat ?? driverLat;
        fLng = pLng ?? driverLng;
        tLat = dLat ?? driverLat;
        tLng = dLng ?? driverLng;
      case 'IN_PROGRESS':
        phase = 'driver_to_drop';
        fLat = driverLat;
        fLng = driverLng;
        tLat = dLat ?? driverLat;
        tLng = dLng ?? driverLng;
      default:
        return;
    }

    final phaseChanged = activePhaseName != phase;
    if (phaseChanged) {
      activePhaseName = phase;
      lastPolylineFetch = null;
      pm.clear();

      if (status == 'IN_PROGRESS' && !is3DMode) is3DMode = true;
      if (status != 'IN_PROGRESS' && is3DMode) {
        is3DMode = false;
        if (pLat != null && dLat != null) {
          resetTo2D([LatLng(pLat, pLng!), LatLng(dLat, dLng!)]);
        }
      }
    }

    // AFTER — for ASSIGNED, re-fetch every 30s (driver is moving toward pickup)
// For IN_PROGRESS, fetch once then stop (route to drop doesn't change much)
if (status == 'IN_PROGRESS' && pm.hasRoute && !phaseChanged) return;

final refreshInterval = status == 'ASSIGNED'
    ? const Duration(seconds: 30)   // re-fetch as driver approaches pickup
    : polylineThrottle;              // 10s for other phases

final now = DateTime.now();
if (!phaseChanged &&
    lastPolylineFetch != null &&
    now.difference(lastPolylineFetch!) < refreshInterval) return;
    if (polylineFetchInFlight) return;
    lastPolylineFetch = now;
    fetchPolyline(fLat, fLng, tLat, tLng);
  }

  Future<void> fetchPolyline(
      double fLat, double fLng, double tLat, double tLng) async {
    polylineFetchInFlight = true;
    try {
      final dir =
          await PlacesService.getDirections(fLat, fLng, tLat, tLng);
      if (dir != null && dir['points'] != null) {
        final pts = (dir['points'] as List)
            .map((p) => LatLng(
                p['latitude'] as double, p['longitude'] as double))
            .toList();
        if (!mounted) return;
        pm.setRoute(pts);
        final visible = pm.trim(LatLng(driverLat, driverLng));
        setState(() {
          polylines =
              visible.length >= 2 ? {buildPolyline(visible)} : {};
        });
        debugPrint(
            '✅ Polyline: ${pts.length} pts total, ${visible.length} remaining');
      }
    } catch (e) {
      debugPrint('⚠️ Polyline fetch error: $e');
    } finally {
      polylineFetchInFlight = false;
    }
  }

  Polyline buildPolyline(List<LatLng> pts) => Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        color: const Color(0xFF000000),
        width: 5,
        geodesic: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      );

  // ═══════════════════════════════════════════════════════
  //  MARKER BUILDER
  // ═══════════════════════════════════════════════════════

  void rebuildMarkers() {
    final ride =
        Provider.of<RideProvider>(context, listen: false).currentRide;
    if (ride == null) return;

    final status = ride['status'] ?? 'SEARCHING';
    final pLat = (ride['pickupLatitude'] as num?)?.toDouble() ?? 12.9716;
    final pLng =
        (ride['pickupLongitude'] as num?)?.toDouble() ?? 77.5946;
    final dLat = (ride['dropLatitude'] as num?)?.toDouble() ?? 12.9816;
    final dLng = (ride['dropLongitude'] as num?)?.toDouble() ?? 77.6046;

    Marker mkDriver() => Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driverLat, driverLng),
          infoWindow:
              InfoWindow(title: ride['driverName'] ?? 'Driver'),
          icon: vehicleIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: driverBearing,
          zIndex: 10,
        );

    Marker mkPickup({double alpha = 1.0}) => Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pLat, pLng),
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 1.0),
          alpha: alpha,
        );

    Marker mkDrop({double alpha = 1.0, String title = 'Drop-off'}) =>
        Marker(
          markerId: const MarkerId('drop'),
          position: LatLng(dLat, dLng),
          infoWindow: InfoWindow(title: title),
          icon: dropIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1.0),
          alpha: alpha,
        );

    final Set<Marker> next;
    switch (status) {
      case 'SEARCHING':
        next = {mkPickup(), mkDrop()};
        WidgetsBinding.instance.addPostFrameCallback((_) =>
            fitBounds([LatLng(pLat, pLng), LatLng(dLat, dLng)]));
      case 'ASSIGNED':
        next = {mkDriver(), mkPickup(), mkDrop(alpha: 0.35)};
        WidgetsBinding.instance.addPostFrameCallback((_) => fitBounds(
            [LatLng(driverLat, driverLng), LatLng(pLat, pLng)]));
      case 'ARRIVED':
        next = {mkDriver(), mkPickup(), mkDrop()};
        WidgetsBinding.instance.addPostFrameCallback((_) =>
            fitBounds([LatLng(pLat, pLng), LatLng(dLat, dLng)]));
      case 'IN_PROGRESS':
        next = {mkDriver(), mkPickup(alpha: 0.2), mkDrop()};
      case 'COMPLETED':
        next = {mkPickup(), mkDrop(title: 'Delivered ✓')};
        polylines = {};
        WidgetsBinding.instance.addPostFrameCallback((_) =>
            fitBounds([LatLng(pLat, pLng), LatLng(dLat, dLng)]));
      default:
        next = {};
    }
    markers = next;
  }

  // ═══════════════════════════════════════════════════════
  //  STATUS + FARE UPDATES
  // ═══════════════════════════════════════════════════════

  void onStatusUpdate(Map<String, dynamic> rideData) {
    if (!mounted) return;
    final rp = Provider.of<RideProvider>(context, listen: false);
    if (rp.currentRide == null) return;

    final cur = rp.currentRide!;
    final statusChanged = cur['status'] != rideData['status'];
    final otpChanged = cur['pickupOtp'] != rideData['pickupOtp'];
    final newLat = (rideData['driverLatitude'] as num?)?.toDouble();
    final newLng = (rideData['driverLongitude'] as num?)?.toDouble();
    final locChanged = newLat != null &&
        newLng != null &&
        ((cur['driverLatitude'] as num?)?.toDouble() != newLat ||
            (cur['driverLongitude'] as num?)?.toDouble() != newLng);

    // Searching progress updates (radius/time remaining) from the cycling matcher
    final isSearchingUpdate = rideData.containsKey('searchRadiusKm');
    if (isSearchingUpdate) {
      final newRadius = (rideData['searchRadiusKm'] as num?)?.toDouble();
      final newRemaining = (rideData['searchTimeRemainingSeconds'] as num?)?.toInt();
      final newCycle = (rideData['searchCycle'] as num?)?.toInt();
      final newRing = (rideData['searchRing'] as num?)?.toInt();
      setState(() {
        if (newRadius != null) searchRadiusKm = newRadius;
        if (newRemaining != null) searchTimeRemaining = newRemaining;
        if (newCycle != null) searchCycle = newCycle;
        if (newRing != null) searchRing = newRing;
      });
      // Start/reset a 1-second countdown for smooth real-time display
      _searchCountdownTimer?.cancel();
      _searchCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && searchTimeRemaining > 0) {
          setState(() => searchTimeRemaining--);
        } else {
          _searchCountdownTimer?.cancel();
        }
      });
      if (!statusChanged && !otpChanged && !locChanged) return;
    }

    // Stop the countdown timer if ride is no longer SEARCHING
    if (statusChanged && rideData['status'] != 'SEARCHING') {
      _searchCountdownTimer?.cancel();
      _searchCountdownTimer = null;
    }

    if (!statusChanged && !otpChanged && !locChanged) return;

    final updated = Map<String, dynamic>.from(cur);
    if (statusChanged) updated['status'] = rideData['status'];
    if (otpChanged && rideData.containsKey('pickupOtp')) {
      updated['pickupOtp'] = rideData['pickupOtp'];
    }

    if (statusChanged && rideData['status'] == 'ASSIGNED') {
      debugPrint('🖼️ ASSIGNED img raw: "${rideData['driverProfileImageUrl']}" '
          'name=${rideData['driverName']} '
          'keys=${rideData.keys.toList()}');
      cachedRideData ??= CachedRideData(
        driverId: rideData['driverId'] ?? '',
        driverName: rideData['driverName'] ?? 'Driver',
        driverImage: rideData['driverProfileImageUrl'] ?? '',
        driverRating: double.parse(
          ((rideData['driverRating'] as num?)?.toDouble() ?? 4.5)
              .toStringAsFixed(1),
        ),
        driverPhone: rideData['driverPhone'] ?? '',
        vehicleType: rideData['vehicleType'] ?? 'CAR',
        vehicleNumber: rideData['vehicleNumber'] ?? '',
        status: rideData['status'],
        currentLat: newLat,
        currentLng: newLng,
      );
      cachedRideData!.save();
      updated
        ..['driverId'] = rideData['driverId']
        ..['driverName'] =
            rideData['driverName'] ?? cur['driverName']
        ..['driverPhone'] =
            rideData['driverPhone'] ?? cur['driverPhone']
        ..['driverImage'] =
            rideData['driverProfileImageUrl'] ?? cur['driverImage']
        ..['driverRating'] =
            rideData['driverRating'] ?? cur['driverRating']
        ..['vehicleNumber'] =
            rideData['vehicleNumber'] ?? cur['vehicleNumber']
        ..['vehicleType'] =
            rideData['vehicleType'] ?? cur['vehicleType'];
    }

    if (locChanged) {
      updated['driverLatitude'] = newLat;
      updated['driverLongitude'] = newLng;
      driverLat = newLat!;
      driverLng = newLng!;
      driverLocationInitialized = true;
      cachedRideData?.updateLocation(newLat, newLng);
    }

    rp.updateCurrentRide(updated);

    if (statusChanged) {
      activePhaseName = null;
      pm.clear();
      if (rideData['status'] == 'IN_PROGRESS') is3DMode = true;
      if (rideData['status'] != 'IN_PROGRESS' && is3DMode) {
        final pLat =
            (updated['pickupLatitude'] as num?)?.toDouble() ?? 12.9716;
        final pLng =
            (updated['pickupLongitude'] as num?)?.toDouble() ?? 77.5946;
        final dLat =
            (updated['dropLatitude'] as num?)?.toDouble() ?? 12.9816;
        final dLng =
            (updated['dropLongitude'] as num?)?.toDouble() ?? 77.6046;
        resetTo2D([LatLng(pLat, pLng), LatLng(dLat, dLng)]);
      }
    }

    setState(() => rebuildMarkers());
    maybeRefreshPolyline(updated['status'], updated);

    if (statusChanged && rideData['status'] == 'ARRIVED') {
      final otp =
          rideData['pickupOtp']?.toString() ?? updated['pickupOtp']?.toString();
      otp != null && otp.isNotEmpty
          ? startOtpCountdown(otp)
          : fetchOtpFromApi(updated['id']?.toString());
    }

    if (statusChanged && rideData['status'] == 'COMPLETED') {
      dr.reset();
      drTimer?.cancel();
      cachedRideData = null;
      CachedRideData.clear();
      cleanupStatic();
      TrackingRouter.close();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/bill-confirmation',
            arguments: updated);
      }
      return;
    }
  }

  void onFareUpdate(Map<String, dynamic> fareData) {
    if (!mounted) return;
    setState(() {
      currentFare = (fareData['actualFare'] as num?)?.toDouble() ??
          currentFare;
    });
  }

  // ═══════════════════════════════════════════════════════
  //  CAMERA
  // ═══════════════════════════════════════════════════════

  void fitBounds(List<LatLng> pts) {
    if (!mapLoaded || mapController == null || pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    const pad = 0.003;
    if ((maxLat - minLat) < pad) {
      minLat -= pad;
      maxLat += pad;
    }
    if ((maxLng - minLng) < pad) {
      minLng -= pad;
      maxLng += pad;
    }
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng)),
        72));
  }

  // ═══════════════════════════════════════════════════════
  //  DATA HELPERS
  // ═══════════════════════════════════════════════════════

  Future<void> fetchLatestRideData(String? rideId) async {
    if (rideId == null) return;
    try {
      final response = await ApiService.getRideStatus(rideId);
      if (!mounted || response == null) return;
      final rp = Provider.of<RideProvider>(context, listen: false);
      final cur = rp.currentRide ?? {};
      final changed = cur['driverId'] != response['driverId'] ||
          cur['driverName'] != response['driverName'] ||
          cur['status'] != response['status'];
      if (!changed) return;
      rp.updateCurrentRide({
        ...cur,
        'driverId': response['driverId'],
        'driverName': response['driverName'],
        'driverPhone': response['driverPhone'],
        'driverRating': response['driverRating'],
        'vehicleNumber': response['vehicleNumber'],
        'vehicleType': response['vehicleType'],
        'driverImage': response['driverProfileImageUrl'],
        'status': response['status'],
        'driverLatitude': response['driverLatitude'],
        'driverLongitude': response['driverLongitude'],
      });
      if (response['status'] == 'ASSIGNED' && cachedRideData == null) {
        cachedRideData = CachedRideData(
          driverId: response['driverId'] ?? '',
          driverName: response['driverName'] ?? 'Driver',
          driverImage: response['driverProfileImageUrl'] ?? '',
          driverRating:
              (response['driverRating'] as num?)?.toDouble() ?? 4.5,
          driverPhone: response['driverPhone'] ?? '',
          vehicleType: response['vehicleType'] ?? 'CAR',
          vehicleNumber: response['vehicleNumber'] ?? '',
          status: response['status'],
          currentLat:
              (response['driverLatitude'] as num?)?.toDouble(),
          currentLng:
              (response['driverLongitude'] as num?)?.toDouble(),
        );
        cachedRideData!.save();
      }
    } catch (e) {
      debugPrint('⚠️ fetchLatestRideData: $e');
    }
  }

  Future<void> fetchOtpFromApi(String? rideId) async {
    if (rideId == null) return;
    try {
      final r = await ApiService.getRideStatus(rideId);
      final otp = r['pickupOtp']?.toString();
      if (otp != null && otp.isNotEmpty && mounted) {
        final rp = Provider.of<RideProvider>(context, listen: false);
        rp.updateCurrentRide({...?rp.currentRide, 'pickupOtp': otp});
        startOtpCountdown(otp);
      }
    } catch (_) {}
  }

  void startOtpCountdown(String? otp) {
    if (otp == null) return;
    otpCountdownTimer?.cancel();
    otpTimeRemaining = 300;
    otpCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => otpTimeRemaining--);
      if (otpTimeRemaining <= 0) {
        t.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('OTP Expired — Request a new one'),
              backgroundColor: TrackingTokens.accentAmber,
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(
                  borderRadius: TrackingTokens.r12)));
        }
      }
    });
  }
}
