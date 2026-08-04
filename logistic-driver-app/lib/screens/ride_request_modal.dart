import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as Math;
import 'dart:async';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';

// ─── Theme tokens — identical across all tabs ─────────────────────────────────
class _T {
  static const bg          = Color(0xFFF5F5F7);
  static const white       = Color(0xFFFFFFFF);
  static const primary     = Color(0xFF1A1A2E);
  static const accent      = Color(0xFFFF6B35);
  static const green       = Color(0xFF00C853);
  static const red         = Color(0xFFFF3B30);
  static const amber       = Color(0xFFFFB300);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x18000000);
  static const divider       = Color(0xFFEEEEEE);
}

class RideRequestModal extends StatefulWidget {
  final String rideId;
  final String pickupAddress;
  final String dropAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropLatitude;
  final double dropLongitude;
  final double estimatedFare;
  final double estimatedDistance;
  final int estimatedDurationMin;
  final double? driverLatitude;
  final double? driverLongitude;

  const RideRequestModal({
    super.key,
    required this.rideId,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropLatitude,
    required this.dropLongitude,
    required this.estimatedFare,
    required this.estimatedDistance,
    required this.estimatedDurationMin,
    this.driverLatitude,
    this.driverLongitude,
  });

  @override
  State<RideRequestModal> createState() => _RideRequestModalState();
}

class _RideRequestModalState extends State<RideRequestModal>
    with SingleTickerProviderStateMixin {

  // ─── All backend/logic state — untouched ─────────────────────────────────
  static const int REQUEST_TIMEOUT_SECONDS = 10;
  bool  _isAccepting      = false;
  int   _secondsRemaining = REQUEST_TIMEOUT_SECONDS;
  late  Timer _countdownTimer;
  bool  _timedOut         = false;

  // ─── UI animation ─────────────────────────────────────────────────────────
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _startCountdown(); // ← original call, unchanged
  }

  // ─── All original logic — NOT A SINGLE LINE CHANGED ──────────────────────

  void _startCountdown() {
    print('⏱️ RIDE REQUEST TIMER STARTED: ${REQUEST_TIMEOUT_SECONDS}s for rideId=${widget.rideId}');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() { _secondsRemaining--; });
      print('⏱️ Countdown: $_secondsRemaining seconds remaining for rideId=${widget.rideId}');
      if (_secondsRemaining <= 0) {
        _countdownTimer.cancel();
        _timedOut = true;
        if (mounted) {
          print('⏱️ RIDE REQUEST TIMEOUT: Closing modal for rideId=${widget.rideId}');
          Navigator.pop(context, false);
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2);
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * Math.pi / 180;

  Future<void> _acceptRide() async {
    print('🔘 ACCEPT BUTTON TAPPED: rideId=${widget.rideId}');
    _countdownTimer.cancel();
    setState(() => _isAccepting = true);
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      print('📤 Calling rideProvider.acceptRide(${widget.rideId})...');
      final ok = await rideProvider.acceptRide(widget.rideId);
      print('📬 Accept result: ok=$ok, error=${rideProvider.error}');
      if (ok && mounted) {
        print('✅ Ride accepted successfully, navigating to active delivery');
        Navigator.pop(context, true);
        Navigator.pushReplacementNamed(context, '/active-delivery');
      } else if (mounted) {
        print('❌ Accept failed with error: ${rideProvider.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rideProvider.error ?? 'Failed to accept ride'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isAccepting = false);
        if (!_timedOut) _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isAccepting = false);
        if (!_timedOut) _startCountdown();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD — UI only redesign
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            decoration: BoxDecoration(
              color: _T.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                _routeSection(),
                _statsBar(),
                _actionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header() {
    final urgent = _secondsRemaining <= 3;
    final timerColor = urgent ? _T.red : _T.amber;
    final progress = _secondsRemaining / REQUEST_TIMEOUT_SECONDS;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: const BoxDecoration(
        color: _T.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(children: [
        // Pulsing alert icon
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _T.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.accent.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.local_shipping_rounded, color: _T.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('New Ride Request',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
              'ID: ${widget.rideId.length >= 8 ? widget.rideId.substring(0, 8).toUpperCase() : widget.rideId.toUpperCase()}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        // Countdown ring
        GestureDetector(
          onTap: () {
            _countdownTimer.cancel();
            Navigator.pop(context, false);
          },
          child: SizedBox(
            width: 48, height: 48,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(timerColor),
                ),
              ),
              Text('${_secondsRemaining}s',
                  style: TextStyle(
                      color: timerColor, fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Route section ─────────────────────────────────────────────────────────
  Widget _routeSection() {
    final hasDriverLoc = widget.driverLatitude != null && widget.driverLongitude != null;
    final distToPickup = hasDriverLoc
        ? _calculateDistance(widget.driverLatitude!, widget.driverLongitude!,
              widget.pickupLatitude, widget.pickupLongitude)
            .toStringAsFixed(1)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(children: [
        // Pickup row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _T.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _T.green.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.radio_button_checked_rounded,
                  color: _T.green, size: 18),
            ),
            // Dashed connector
            ...List.generate(4, (_) => Container(
              width: 1.5, height: 5,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: _T.divider,
            )),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PICKUP',
                    style: TextStyle(
                        color: _T.textSecondary, fontSize: 9,
                        letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(widget.pickupAddress,
                    style: const TextStyle(
                        color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (distToPickup != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.directions_car_rounded,
                        color: _T.accent, size: 11),
                    const SizedBox(width: 4),
                    Text('$distToPickup km away',
                        style: const TextStyle(
                            color: _T.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ],
                const SizedBox(height: 14),
              ]),
            ),
          ),
        ]),

        // Drop row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _T.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _T.red.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.location_on_rounded, color: _T.red, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('DROP',
                    style: TextStyle(
                        color: _T.textSecondary, fontSize: 9,
                        letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(widget.dropAddress,
                    style: const TextStyle(
                        color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Stats bar ─────────────────────────────────────────────────────────────
  Widget _statsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        _statCell(Icons.straighten_rounded, _T.textSecondary,
            '${widget.estimatedDistance.toStringAsFixed(1)} km', 'Distance'),
        _vDivider(),
        _statCell(Icons.access_time_rounded, _T.textSecondary,
            '~${widget.estimatedDurationMin} min', 'Est. Time'),
        _vDivider(),
        _statCell(Icons.currency_rupee_rounded, _T.accent,
            '₹${widget.estimatedFare.toStringAsFixed(0)}', 'Fare',
            highlight: true),
      ]),
    );
  }

  Widget _statCell(IconData icon, Color color, String value, String label,
      {bool highlight = false}) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
                color: highlight ? _T.accent : _T.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: _T.textSecondary, fontSize: 10)),
      ]),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 36, color: _T.divider);

  // ── Action buttons ────────────────────────────────────────────────────────
  Widget _actionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(children: [
        // Accept button
        GestureDetector(
          onTap: _isAccepting || _timedOut ? null : _acceptRide,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: _isAccepting || _timedOut
                  ? _T.textHint
                  : _T.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isAccepting || _timedOut ? [] : [
                BoxShadow(
                    color: _T.primary.withValues(alpha: 0.25),
                    blurRadius: 14, offset: const Offset(0, 5)),
              ],
            ),
            child: Center(
              child: _isAccepting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _timedOut ? 'Request Expired' : 'Accept Ride',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Reject button
        GestureDetector(
          onTap: _isAccepting || _timedOut ? null : () {
            _countdownTimer.cancel();
            Navigator.pop(context, false);
          },
          child: Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _T.divider, width: 1.5),
            ),
            child: const Center(
              child: Text('Decline',
                  style: TextStyle(
                      color: _T.textSecondary, fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}