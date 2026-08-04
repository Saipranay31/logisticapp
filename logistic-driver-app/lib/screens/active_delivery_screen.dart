import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/websocket_service.dart';
import '../services/places_service.dart';

import 'active_delivery/delivery_tokens.dart';
import 'active_delivery/delivery_helpers.dart';
import 'active_delivery/widgets/delivery_common_widgets.dart';
import 'active_delivery/widgets/delivery_status_pill.dart';
import 'active_delivery/widgets/delivery_eta_badge.dart';
import 'active_delivery/widgets/delivery_map_controls.dart';
import 'active_delivery/widgets/delivery_bottom_sheet.dart';
import 'active_delivery/widgets/phase_heading_pickup.dart';
import 'active_delivery/widgets/phase_at_pickup.dart';
import 'active_delivery/widgets/phase_in_transit.dart';
import 'active_delivery/widgets/phase_completed.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key});
  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen>
    with TickerProviderStateMixin {

  // ── Flow status ──────────────────────────────────────────────────────────
  String _status = 'HEADING_TO_PICKUP';

  // ── Screen state ─────────────────────────────────────────────────────────
  final _otpCtrl = TextEditingController();
  int _customerRating = 0;
  bool _isLoading = false;
  final LocationService _locationService = LocationService();

  double _baseFare = 50.0, _perKmRate = 12.0, _perMinRate = 2.0;
  double _distanceTraveled = 0.0;
  int    _timeElapsed = 0;
  double _distanceCharge = 0.0, _timeCharge = 0.0, _totalEarnings = 0.0;
  DateTime? _lastFareUpdate;

  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  bool _mapLoaded = false;

  // ── Nav cam ───────────────────────────────────────────────────────────────
  bool _navMode = true;

  // ── Custom icons ──────────────────────────────────────────────────────────
  BitmapDescriptor? _selfIcon, _pickupIcon, _dropIcon;

  // ── Smooth marker animation ───────────────────────────────────────────────
  late AnimationController _markerAnim;
  Animation<double>? _latTween, _lngTween;

  LatLng _animatedPos = const LatLng(0, 0);
  bool   _animPosInit = false;

  // ── Dead reckoning ────────────────────────────────────────────────────────
  late DeadReckoningEngine _dr;
  Timer? _drTimer;

  // ── Polyline manager ──────────────────────────────────────────────────────
  final _pm = PolylineManager();
  String?   _activePhase;
  DateTime? _lastPolylineFetch;
  bool      _polylineFetching = false;
  static const _polylineThrottle = Duration(seconds: 15);

  // ── Own GPS ───────────────────────────────────────────────────────────────
  double _myLat = 0, _myLng = 0, _myBearing = 0.0;
  bool   _myLocInit = false;
  StreamSubscription<Position>? _gpsSub;

  // ── Redis broadcaster ─────────────────────────────────────────────────────
  final _redisBroadcaster = RedisLocationBroadcaster();

  // ── ETA ───────────────────────────────────────────────────────────────────
  String _etaLabel = '';

  // ── Bottom sheet animation ────────────────────────────────────────────────
  late AnimationController _sheetAnim;

  // ── Pickup/drop coords ────────────────────────────────────────────────────
  double _pLat = 0, _pLng = 0, _dLat = 0, _dLng = 0;

  // ═══════════════════════════════════════════════════════════════════════════
  //  INIT / DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _dr = DeadReckoningEngine(lat: 0, lng: 0);

    _markerAnim = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this)
      ..addListener(_onMarkerTick);

    _sheetAnim = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this)
      ..forward();

    _initializeLocationService();
    _loadFareConfiguration();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RideProvider>(context, listen: false).setNavContext(context);
      final ride = Provider.of<RideProvider>(context, listen: false).currentRide;
      if (ride != null) {
        _pLat = (ride['pickupLatitude']  as num?)?.toDouble() ?? 0;
        _pLng = (ride['pickupLongitude'] as num?)?.toDouble() ?? 0;
        _dLat = (ride['dropLatitude']    as num?)?.toDouble() ?? 0;
        _dLng = (ride['dropLongitude']   as num?)?.toDouble() ?? 0;

        final rideStatus = ride['status']?.toString() ?? '';
        setState(() {
          _status = switch (rideStatus) {
            'ASSIGNED'    => 'HEADING_TO_PICKUP',
            'ARRIVED'     => 'AT_PICKUP',
            'IN_PROGRESS' => 'IN_TRANSIT',
            'COMPLETED'   => 'COMPLETED',
            _             => 'HEADING_TO_PICKUP',
          };
          _totalEarnings = (ride['estimatedFare'] as num?)?.toDouble() ?? 50.0;
          _navMode = (_status == 'HEADING_TO_PICKUP' || _status == 'IN_TRANSIT');
        });

        if (rideStatus == 'COMPLETED') _locationService.stopTracking();

        _startLocationTracking(
          ride['id'].toString(),
          driverId: ride['driverId']?.toString(),
        );
        _initIcons(ride['vehicleType']?.toString());
        _startOwnGps(ride);
      }
    });
  }

  @override
  void dispose() {
    _markerAnim..removeListener(_onMarkerTick)..dispose();
    _sheetAnim.dispose();
    _drTimer?.cancel();
    _gpsSub?.cancel();
    _mapCtrl?.dispose();
    _otpCtrl.dispose();
    _redisBroadcaster.stop();
    _locationService.stopTracking();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FARE / LOCATION SERVICE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _initializeLocationService() async {
    try { await _locationService.initialize(); }
    catch (e) { debugPrint('Location init: $e'); }
  }

  Future<void> _loadFareConfiguration() async {
    try {
      final config = await ApiService.getFareConfig();
      if (mounted) setState(() {
        _baseFare   = (config['baseFare']   as num?)?.toDouble() ?? 50.0;
        _perKmRate  = (config['perKmRate']  as num?)?.toDouble() ?? 12.0;
        _perMinRate = (config['perMinRate'] as num?)?.toDouble() ?? 2.0;
      });
    } catch (e) { debugPrint('⚠️ Fare config: $e'); }
  }

  void _initializeEarningsFromRide(Map<String, dynamic> ride) {
    if (mounted) setState(() {
      _totalEarnings    = (ride['estimatedFare'] as num?)?.toDouble() ?? _baseFare;
      _distanceTraveled = 0.0;
      _timeElapsed      = 0;
      _lastFareUpdate   = DateTime.now();
    });
  }

  void _startLocationTracking(String rideId, {String? driverId}) {
    _locationService.startTracking(rideId, driverId: driverId);
    _subscribeToFareUpdates(rideId);
  }

  void _subscribeToFareUpdates(String rideId) {
    try { WebSocketService.subscribeToRideFare(rideId, _onFareUpdate); }
    catch (e) { debugPrint('❌ WS subscribe: $e'); }
  }

  void _onFareUpdate(Map<String, dynamic> fareData) {
    if (!mounted) return;
    setState(() {
      _distanceTraveled = (fareData['distanceTraveled'] as num?)?.toDouble() ?? _distanceTraveled;
      _timeElapsed      = (fareData['timeElapsed']      as num?)?.toInt()    ?? _timeElapsed;
      _distanceCharge   = _distanceTraveled * _perKmRate;
      _timeCharge       = (_timeElapsed / 60.0) * _perMinRate;
      if (fareData['actualFare'] != null && (fareData['actualFare'] as num) > 0) {
        _totalEarnings = (fareData['actualFare'] as num).toDouble();
      } else {
        _totalEarnings = _baseFare + _distanceCharge + _timeCharge;
      }
      _lastFareUpdate = DateTime.now();
    });
  }

  Future<void> _submitRating() async {
    if (_customerRating == 0) return;
    try {
      final rp = Provider.of<RideProvider>(context, listen: false);
      if (rp.currentRide != null) {
        await ApiService.rateUser(rp.currentRide!['id'], _customerRating);
      }
    } catch (e) { debugPrint('❌ Rating: $e'); }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GPS — real fixes feed DR + Redis
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startOwnGps(Map<String, dynamic> ride) async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        status = await Geolocator.requestPermission();
      }
      if (status == LocationPermission.deniedForever) return;

      _redisBroadcaster.start(
        ride['id'].toString(), ride['driverId']?.toString());

      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 8));
        _applyOwnPosition(pos.latitude, pos.longitude, pos.accuracy, true);
      } catch (e) {
        debugPrint('⚠️ First fix failed: $e');
      }

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen((pos) =>
          _applyOwnPosition(pos.latitude, pos.longitude, pos.accuracy, true));

    } catch (e) { debugPrint('⚠️ GPS: $e'); }
  }

  void _applyOwnPosition(double newLat, double newLng,
      [double accuracy = 10, bool isRealGps = true]) {
    if (!mounted) return;

    if (isRealGps && _myLocInit &&
        haversineM(_myLat, _myLng, newLat, newLng) < 0.5) return;

    if (isRealGps) {
      _dr.updateFix(newLat, newLng);
      _myBearing = _dr.bearing;
      _redisBroadcaster.updatePosition(newLat, newLng, _myBearing, _dr.speedMs);
    }

    _myLat = newLat; _myLng = newLng;

    if (!_myLocInit) {
      _myLocInit = true;
      _animatedPos = LatLng(newLat, newLng);
      _animPosInit = true;
      _dr = DeadReckoningEngine(lat: newLat, lng: newLng);

      setState(() => _rebuildMarkersAt(_animatedPos));

      if (_mapLoaded && _mapCtrl != null) {
        if (_navMode) {
          _enterNavCam(newLat, newLng, _myBearing);
        } else {
          _fitBoundsForPhase();
        }
      }

      _startDeadReckoning();
      _forceRefreshPolyline();
      return;
    }

    _animateMarker(newLat, newLng);

    if (isRealGps && _pm.hasRoute) {
      final remaining = _pm.trim(LatLng(newLat, newLng));
      if (remaining.length >= 2) {
        setState(() => _polylines = _buildNavPolylines(remaining));
      }
    }

    if (_navMode && _mapLoaded) {
      _enterNavCam(newLat, newLng, _myBearing);
    }

    if (isRealGps) _maybeRefreshPolyline();
  }

  // ── Dead reckoning ────────────────────────────────────────────────────────

  void _startDeadReckoning() {
    _drTimer?.cancel();
    _drTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !_dr.active || !_myLocInit) return;
      final predicted = _dr.predict();
      if (haversineM(
          _animatedPos.latitude, _animatedPos.longitude,
          predicted.latitude,   predicted.longitude) < 0.3) return;
      _animateMarker(predicted.latitude, predicted.longitude);
    });
  }

  // ── Marker animation ──────────────────────────────────────────────────────

  void _onMarkerTick() {
    if (_latTween == null || _lngTween == null || !mounted) return;
    _animatedPos = LatLng(_latTween!.value, _lngTween!.value);
    _rebuildMarkersAt(_animatedPos);
    setState(() {});
  }

  void _animateMarker(double tLat, double tLng) {
    final fromLat = _animPosInit ? _animatedPos.latitude  : tLat;
    final fromLng = _animPosInit ? _animatedPos.longitude : tLng;

    _markerAnim.stop();
    _latTween = Tween<double>(begin: fromLat, end: tLat)
        .animate(CurvedAnimation(parent: _markerAnim, curve: Curves.easeOutCubic));
    _lngTween = Tween<double>(begin: fromLng, end: tLng)
        .animate(CurvedAnimation(parent: _markerAnim, curve: Curves.easeOutCubic));
    _markerAnim..reset()..forward();
  }

  // ── Marker rebuild ────────────────────────────────────────────────────────

  void _rebuildMarkersAt(LatLng pos) {
    Marker mkSelf() => Marker(
      markerId: const MarkerId('self'),
      position: pos,
      icon: _selfIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      anchor: const Offset(0.5, 0.5),
      flat: true,
      rotation: _myBearing,
      zIndex: 10,
    );
    Marker mkPickup({double alpha = 1.0}) => Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(_pLat != 0 ? _pLat : 12.97, _pLng != 0 ? _pLng : 77.59),
      infoWindow: const InfoWindow(title: 'Pickup'),
      icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      anchor: const Offset(0.5, 1.0),
      alpha: alpha,
    );
    Marker mkDrop({double alpha = 1.0}) => Marker(
      markerId: const MarkerId('drop'),
      position: LatLng(_dLat != 0 ? _dLat : 12.98, _dLng != 0 ? _dLng : 77.60),
      infoWindow: const InfoWindow(title: 'Drop-off'),
      icon: _dropIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: const Offset(0.5, 1.0),
      alpha: alpha,
    );

    _markers = switch (_status) {
      'HEADING_TO_PICKUP' => {if (_myLocInit) mkSelf(), mkPickup(), mkDrop(alpha: 0.3)},
      'AT_PICKUP'         => {if (_myLocInit) mkSelf(), mkPickup(), mkDrop()},
      'IN_TRANSIT'        => {if (_myLocInit) mkSelf(), mkPickup(alpha: 0.2), mkDrop()},
      'COMPLETED'         => {mkPickup(), mkDrop()},
      _                   => {if (_myLocInit) mkSelf(), mkPickup(), mkDrop()},
    };
  }

  void _fitBoundsForPhase() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapLoaded || _mapCtrl == null) return;
      final List<LatLng> pts;
      switch (_status) {
        case 'HEADING_TO_PICKUP':
          if (!_myLocInit || _pLat == 0) return;
          pts = [LatLng(_myLat, _myLng), LatLng(_pLat, _pLng)];
        case 'AT_PICKUP':
          if (_pLat == 0 || _dLat == 0) return;
          pts = [LatLng(_pLat, _pLng), LatLng(_dLat, _dLng)];
        case 'IN_TRANSIT':
          if (!_myLocInit || _dLat == 0) return;
          pts = [LatLng(_myLat, _myLng), LatLng(_dLat, _dLng)];
        default:
          if (_pLat == 0 || _dLat == 0) return;
          pts = [LatLng(_pLat, _pLng), LatLng(_dLat, _dLng)];
      }
      _fitBounds(pts);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  POLYLINE
  // ═══════════════════════════════════════════════════════════════════════════

  void _forceRefreshPolyline() {
    if (!_myLocInit && (_status == 'HEADING_TO_PICKUP' || _status == 'IN_TRANSIT')) return;
    if (_pLat == 0 || _pLng == 0) return;

    switch (_status) {
      case 'HEADING_TO_PICKUP':
        _activePhase = 'to_pickup';
        _lastPolylineFetch = DateTime.now();
        _fetchPolyline(_myLat, _myLng, _pLat, _pLng);
      case 'AT_PICKUP':
        _activePhase = 'pickup_to_drop';
        _lastPolylineFetch = DateTime.now();
        _fetchPolyline(_pLat, _pLng, _dLat, _dLng);
      case 'IN_TRANSIT':
        _activePhase = 'to_drop';
        _lastPolylineFetch = DateTime.now();
        _fetchPolyline(_myLat, _myLng, _dLat, _dLng);
      default:
        setState(() => _polylines = {});
    }
  }

  void _maybeRefreshPolyline() {
    if (_pLat == 0) return;

    late String phase; late double fLat, fLng, tLat, tLng;
    switch (_status) {
      case 'HEADING_TO_PICKUP':
        phase = 'to_pickup';
        fLat = _myLat; fLng = _myLng; tLat = _pLat; tLng = _pLng;
      case 'AT_PICKUP':
        phase = 'pickup_to_drop';
        fLat = _pLat; fLng = _pLng; tLat = _dLat; tLng = _dLng;
      case 'IN_TRANSIT':
        phase = 'to_drop';
        fLat = _myLat; fLng = _myLng; tLat = _dLat; tLng = _dLng;
      default:
        setState(() => _polylines = {}); return;
    }

    final phaseChanged = _activePhase != phase;
    if (phaseChanged) {
      _activePhase = phase;
      _lastPolylineFetch = null;
      _pm.clear();
      _fetchPolyline(fLat, fLng, tLat, tLng);
      _lastPolylineFetch = DateTime.now();
      return;
    }

    if (_status == 'IN_TRANSIT' && _pm.hasRoute) return;

    final now = DateTime.now();
    if (_lastPolylineFetch != null &&
        now.difference(_lastPolylineFetch!) < _polylineThrottle) return;
    if (_polylineFetching) return;

    _lastPolylineFetch = now;
    _fetchPolyline(fLat, fLng, tLat, tLng);
  }

  Future<void> _fetchPolyline(
      double fLat, double fLng, double tLat, double tLng) async {
    if (fLat == 0 || tLat == 0 || fLng == 0 || tLng == 0) return;
    if (_polylineFetching) return;
    _polylineFetching = true;
    debugPrint('🗺️ Fetching polyline: ($fLat,$fLng) → ($tLat,$tLng)');
    try {
      final dir = await PlacesService.getDirections(fLat, fLng, tLat, tLng);
      if (dir != null && dir['points'] != null) {
        final pts = (dir['points'] as List)
            .map((p) => LatLng(
                p['latitude'] as double, p['longitude'] as double))
            .toList();
        if (!mounted) return;
        _pm.setRoute(pts);

        final trimPos = (_status == 'AT_PICKUP')
            ? LatLng(fLat, fLng)
            : LatLng(_myLat, _myLng);
        final visible = _pm.trim(trimPos);

        setState(() => _polylines = _buildNavPolylines(visible));

        final eta = dir['duration'] ?? dir['durationText'];
        if (eta != null) setState(() => _etaLabel = eta.toString());

        debugPrint('✅ Polyline: ${pts.length} pts, visible: ${visible.length}');
      }
    } catch (e) { debugPrint('⚠️ Polyline fetch: $e'); }
    finally { _polylineFetching = false; }
  }

  Set<Polyline> _buildNavPolylines(List<LatLng> pts) {
    if (pts.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route_outline'),
        points: pts,
        color: Colors.white.withOpacity(0.7),
        width: 11, geodesic: true,
        startCap: Cap.roundCap, endCap: Cap.roundCap,
        jointType: JointType.round, zIndex: 0,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        color: const Color(0xFF1A73E8),
        width: 7, geodesic: true,
        startCap: Cap.roundCap, endCap: Cap.roundCap,
        jointType: JointType.round, zIndex: 1,
      ),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CAMERA
  // ═══════════════════════════════════════════════════════════════════════════

  void _enterNavCam(double lat, double lng, double bearing) {
    _mapCtrl?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(lat, lng),
        zoom: 17.5, tilt: 60, bearing: bearing,
      ),
    ));
  }

  void _fitBounds(List<LatLng> pts) {
    if (!_mapLoaded || _mapCtrl == null || pts.length < 2) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    const pad = 0.003;
    if (maxLat - minLat < pad) { minLat -= pad; maxLat += pad; }
    if (maxLng - minLng < pad) { minLng -= pad; maxLng += pad; }
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      100,
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ICONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _initIcons(String? vehicleType) async {
    await Future.wait([
      _createSelfIcon(vehicleType),
      _createPickupIcon(),
      _createDropIcon(),
    ]);
    if (mounted) setState(() => _rebuildMarkersAt(_animatedPos));
  }

  Future<void> _createSelfIcon(String? type) async {
    try {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const s = 120.0;
      c.drawCircle(const Offset(s / 2 + 2, s / 2 + 3), 34,
        Paint()..color = Colors.black.withOpacity(0.2)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      c.drawCircle(const Offset(s / 2, s / 2), 34,
        Paint()..color = Colors.white);
      c.drawCircle(const Offset(s / 2, s / 2), 34,
        Paint()..color = const Color(0xFF1A73E8).withOpacity(0.6)
               ..style = PaintingStyle.stroke..strokeWidth = 2.5);
      c.drawCircle(const Offset(s / 2, s / 2), 26,
        Paint()..color = const Color(0xFF1A73E8).withOpacity(0.12));
      final emoji = switch (type) {
        'BIKE' => '🏍️', 'AUTO' => '🛺',
        'MINI_TRUCK' => '🚚', 'TRUCK' => '🚛', _ => '🚗',
      };
      final tp = TextPainter(
        text: TextSpan(text: emoji,
          style: const TextStyle(fontSize: 28)),
        textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset((s - tp.width) / 2, (s - tp.height) / 2 - 1));
      final img   = await rec.endRecording().toImage(s.toInt(), s.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null && mounted) {
        setState(() =>
          _selfIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List()));
      }
    } catch (_) {
      _selfIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<void> _createPickupIcon() async {
    try {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const w = 80.0, h = 96.0;
      c.drawPath(
        Path()..addOval(Rect.fromCenter(
          center: const Offset(w / 2 + 1, h - 8), width: 20, height: 6)),
        Paint()..color = Colors.black.withOpacity(0.15)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      final p = Paint()..color = const Color(0xFF34A853);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w / 2 - 22, 0, 44, 44),
          const Radius.circular(12)), p);
      c.drawPath(
        Path()..moveTo(w / 2 - 10, 40)
              ..lineTo(w / 2, h - 12)
              ..lineTo(w / 2 + 10, 40)..close(), p);
      c.drawCircle(Offset(w / 2, 22), 14, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: const TextSpan(text: 'P',
          style: TextStyle(color: Color(0xFF34A853), fontSize: 16,
            fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(w / 2 - tp.width / 2, 22 - tp.height / 2));
      final img   = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        _pickupIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      }
    } catch (_) {
      _pickupIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  Future<void> _createDropIcon() async {
    try {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const w = 80.0, h = 96.0;
      c.drawPath(
        Path()..addOval(Rect.fromCenter(
          center: const Offset(w / 2 + 1, h - 8), width: 20, height: 6)),
        Paint()..color = Colors.black.withOpacity(0.15)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      final p = Paint()..color = const Color(0xFFEA4335);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w / 2 - 22, 0, 44, 44),
          const Radius.circular(12)), p);
      c.drawPath(
        Path()..moveTo(w / 2 - 10, 40)
              ..lineTo(w / 2, h - 12)
              ..lineTo(w / 2 + 10, 40)..close(), p);
      c.drawCircle(Offset(w / 2, 22), 14, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: const TextSpan(text: 'D',
          style: TextStyle(color: Color(0xFFEA4335), fontSize: 16,
            fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(w / 2 - tp.width / 2, 22 - tp.height / 2));
      final img   = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        _dropIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      }
    } catch (_) {
      _dropIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PHASE ACTION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _doArriveAtPickup(RideProvider rp) async {
    setState(() => _isLoading = true);
    try {
      if (rp.currentRide != null) {
        await rp.arriveAtPickup(rp.currentRide!['id'].toString());
      }
      _pm.clear();
      _activePhase = null;
      _lastPolylineFetch = null;
      setState(() {
        _status   = 'AT_PICKUP';
        _isLoading = false;
        _navMode  = false;
        _polylines = {};
      });
      _rebuildMarkersAt(_animatedPos);
      _fitBoundsForPhase();
      _forceRefreshPolyline();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('$e');
    }
  }

  Future<void> _doVerifyOtp(RideProvider rp) async {
    if (_otpCtrl.text.length < 4) {
      _showError('Enter 4-digit OTP from customer'); return;
    }
    if (rp.currentRide?['status'] != 'ARRIVED') {
      _showError('Arrive at pickup first'); return;
    }
    setState(() => _isLoading = true);
    try {
      await rp.startRide(rp.currentRide!['id'].toString(), _otpCtrl.text);
      _initializeEarningsFromRide(rp.currentRide!);
      _pm.clear();
      _activePhase = null;
      _lastPolylineFetch = null;
      setState(() {
        _status    = 'IN_TRANSIT';
        _isLoading = false;
        _navMode   = true;
        _polylines = {};
      });
      _rebuildMarkersAt(_animatedPos);
      _forceRefreshPolyline();
      if (_mapLoaded && _myLocInit) {
        _enterNavCam(_myLat, _myLng, _myBearing);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _otpCtrl.clear();
      _showError('Invalid OTP — please try again');
    }
  }

  Future<void> _doCompleteRide(RideProvider rp) async {
    setState(() => _isLoading = true);
    _redisBroadcaster.stop();
    _drTimer?.cancel();
    _locationService.stopTracking();
    setState(() { _navMode = false; _polylines = {}; });
    try {
      if (rp.currentRide != null) {
        await rp.completeRide(rp.currentRide!['id'].toString());
      }
      _pm.clear();
      setState(() { _status = 'COMPLETED'; _isLoading = false; });
      _rebuildMarkersAt(_animatedPos);
      _fitBoundsForPhase();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('$e');
    }
  }

  Future<void> _doConfirmCash(String rideId, RideProvider rp) async {
    try {
      await ApiService.confirmCashPayment(rideId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Payment confirmed!'),
        backgroundColor: DT.green));
      final updated = await ApiService.getRide(rideId);
      rp.updateCurrentRide({
        ...?rp.currentRide,
        'paymentStatus': updated.paymentStatus,
        'actualFare':    updated.actualFare,
      });
      if (mounted) setState(() {});
    } catch (e) { _showError('$e'); }
  }

  Future<void> _doFinishAndGoHome(RideProvider rp) async {
    if (_customerRating > 0) await _submitRating();
    rp.clearRide();
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _openMapsTo(double lat, double lng) async {
    final nav = 'google.navigation:q=$lat,$lng&mode=d';
    final web = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    try {
      if (await canLaunchUrl(Uri.parse(nav))) {
        await launchUrl(Uri.parse(nav), mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(web), mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: DT.red,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: DT.r12),
      margin: const EdgeInsets.all(16),
    ));
  }

  double _bottomSheetHeight() => switch (_status) {
    'HEADING_TO_PICKUP' => 290,
    'AT_PICKUP'         => 380,
    'IN_TRANSIT'        => 300,
    'COMPLETED'         => 440,
    _                   => 290,
  };

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DT.bg,
        extendBodyBehindAppBar: true,
        body: Consumer<RideProvider>(builder: (_, rp, __) {
          final r = rp.currentRide;
          if (r == null) return const DeliveryEmptyState();

          final userName  = r['userName']  ?? r['userId'] ?? 'Customer';
          final userPhone = r['userPhone'] ?? '';
          final userRating = (r['userRating'] as num?)?.toDouble();
          final fare = (r['actualFare'] as num?)?.toDouble()
              ?? (r['estimatedFare'] as num?)?.toDouble()
              ?? _totalEarnings;

          final initLat = _myLocInit ? _myLat : (_pLat != 0 ? _pLat : 17.385);
          final initLng = _myLocInit ? _myLng : (_pLng != 0 ? _pLng : 78.486);

          return Stack(children: [

            // ── Full-screen map ────────────────────────────────────────────
            SizedBox.expand(
              child: GoogleMap(
                onMapCreated: (ctrl) {
                  _mapCtrl = ctrl;
                  _mapLoaded = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _rebuildMarkersAt(_animatedPos));
                    if (_myLocInit) {
                      if (_navMode) {
                        _enterNavCam(_myLat, _myLng, _myBearing);
                      } else {
                        _fitBoundsForPhase();
                      }
                      _forceRefreshPolyline();
                    } else if (_pLat != 0 && _dLat != 0) {
                      _fitBounds([LatLng(_pLat, _pLng), LatLng(_dLat, _dLng)]);
                    }
                  });
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(initLat, initLng),
                  zoom: 15.0,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                style: _mapStyle(),
              ),
            ),

            // ── GPS loading indicator ──────────────────────────────────────
            if (!_myLocInit)
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                left: 0, right: 0,
                child: const GpsLoadingIndicator(),
              ),

            // ── Status pill ────────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16,
              child: DeliveryStatusPill(status: _status, fare: fare),
            ),

            // ── ETA badge ──────────────────────────────────────────────────
            if (_etaLabel.isNotEmpty &&
                _status != 'COMPLETED' && _status != 'AT_PICKUP')
              Positioned(
                top: MediaQuery.of(context).padding.top + 68,
                left: 16,
                child: DeliveryEtaBadge(etaLabel: _etaLabel),
              ),

            // ── Map controls ───────────────────────────────────────────────
            Positioned(
              right: 14,
              bottom: _bottomSheetHeight() + 20,
              child: DeliveryMapControls(
                navMode: _navMode,
                myLocInit: _myLocInit,
                onCenter: () {
                  if (!_myLocInit) return;
                  setState(() => _navMode = true);
                  _enterNavCam(_myLat, _myLng, _myBearing);
                },
                onOverview: () {
                  setState(() => _navMode = false);
                  _fitBoundsForPhase();
                },
                onOpenMaps: () {
                  final tLat = _status == 'HEADING_TO_PICKUP' ? _pLat : _dLat;
                  final tLng = _status == 'HEADING_TO_PICKUP' ? _pLng : _dLng;
                  _openMapsTo(tLat, tLng);
                },
                onBack: () => Navigator.pop(context),
              ),
            ),

            // ── Bottom sheet ───────────────────────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: DeliveryBottomSheet(
                animation: _sheetAnim,
                userName: userName,
                userPhone: userPhone,
                userRating: userRating,
                fare: fare,
                status: _status,
                pickupAddress: r['pickupAddress'] ?? 'Pickup',
                dropAddress: r['dropAddress'] ?? 'Drop',
                bottomPadding: MediaQuery.of(context).padding.bottom,
                onChat: () => Navigator.pushNamed(context, '/driver-chat'),
                phaseContent: _buildPhaseContent(r, rp, fare),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _buildPhaseContent(
      Map<String, dynamic> r, RideProvider rp, double fare) {
    return switch (_status) {
      'HEADING_TO_PICKUP' => PhaseHeadingToPickup(
        isLoading: _isLoading,
        etaLabel:  _etaLabel,
        onOpenMaps: () => _openMapsTo(_pLat, _pLng),
        onArrived:  () => _doArriveAtPickup(rp),
      ),
      'AT_PICKUP' => PhaseAtPickup(
        isLoading:   _isLoading,
        otpCtrl:     _otpCtrl,
        onVerifyOtp: () => _doVerifyOtp(rp),
      ),
      'IN_TRANSIT' => PhaseInTransit(
        isLoading:       _isLoading,
        distanceTraveled: _distanceTraveled,
        onOpenMaps:       () => _openMapsTo(_dLat, _dLng),
        onArrivedAtDrop:  () => _doCompleteRide(rp),
      ),
      'COMPLETED' => PhaseCompleted(
        ride:             r,
        fare:             fare,
        distanceTraveled: _distanceTraveled,
        timeElapsed:      _timeElapsed.toDouble(),
        distanceCharge:   _distanceCharge,
        timeCharge:       _timeCharge,
        customerRating:   _customerRating,
        onRatingChanged:  (v) => setState(() => _customerRating = v),
        onComplete:       () => _doFinishAndGoHome(rp),
        onConfirmCash:    (id) => _doConfirmCash(id, rp),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MAP STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  String _mapStyle() => '''[
    {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
    {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
    {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5f5e0"}]},
    {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#4caf50"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#ffd54f"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#ffb300"}]},
    {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
    {"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e0e0e0"}]},
    {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b3d9f7"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#5b8fa8"}]},
    {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#f0f0f0"}]},
    {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#e8f5e9"}]}
  ]''';
}
