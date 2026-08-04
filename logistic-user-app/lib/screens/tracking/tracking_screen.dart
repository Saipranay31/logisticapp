import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/api_service.dart';
import '../../screens/home_screen.dart'; // for TrackingRouter
import 'tracking_tokens.dart';
import 'tracking_map_style.dart';
import 'tracking_screen_controller.dart';
import 'tracking_shared_widgets.dart';
import 'otp_card_widget.dart';
import 'driver_card_widget.dart';
import 'progress_stepper_widget.dart';

// ═══════════════════════════════════════════════════════════
//  TRACKING SCREEN
// ═══════════════════════════════════════════════════════════

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin, TrackingScreenController {
  // ── Aliases so private _T refs become TrackingTokens ─────
  // (keeps build methods unchanged)
  static const _T = TrackingTokens;

  // ═══════════════════════════════════════════════════════
  //  INIT / DISPOSE
  // ═══════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    controllerInit();
  }

  @override
  void dispose() {
    controllerDispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrackingTokens.sheetBg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Consumer<RideProvider>(builder: (_, rp, __) {
        final r = rp.currentRide;
        if (r == null) return _buildEmptyState();

        final status = r['status'] ?? 'SEARCHING';
        return Stack(children: [
          _buildMap(r),
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildStatusPill(status),
          ),
          if (is3DMode)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 56,
              right: 16,
              child: _build3DBadge(),
            ),
          Positioned(
            right: 14,
            bottom: _bottomPanelEstimatedHeight(status) + 16,
            child: _buildMapControls(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(r, status),
          ),
        ]);
      }),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
              color: TrackingTokens.offWhite, shape: BoxShape.circle),
          child: const Icon(Icons.local_shipping_outlined,
              color: TrackingTokens.inkLight, size: 48),
        ),
        const SizedBox(height: 20),
        const Text('No active delivery',
            style: TextStyle(
                color: TrackingTokens.ink,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('You have no ongoing ride',
            style:
                TextStyle(color: TrackingTokens.inkLight, fontSize: 14)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: TrackingTokens.accent,
            foregroundColor: TrackingTokens.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: const RoundedRectangleBorder(
                borderRadius: TrackingTokens.r12),
            elevation: 0,
          ),
          child: const Text('Go Back',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  APP BAR
  // ═══════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: TrackingGlassButton(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded,
              color: TrackingTokens.ink, size: 20),
        ),
      ),
      title: const Text('Live Tracking',
          style: TextStyle(
              color: TrackingTokens.ink,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.3)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TrackingGlassButton(
            onTap: () {},
            child: const Icon(Icons.share_rounded,
                color: TrackingTokens.inkMid, size: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: TrackingGlassButton(
            onTap: () => _showSosDialog(context),
            child:
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  MAP
  // ═══════════════════════════════════════════════════════

  Widget _buildMap(Map<String, dynamic> r) {
    return SizedBox.expand(
      child: GoogleMap(
        onMapCreated: (c) {
          mapController = c;
          mapLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => rebuildMarkers());
              final ride = Provider.of<RideProvider>(context, listen: false)
                  .currentRide;
              if (ride != null) {
                maybeRefreshPolyline(ride['status'], ride);
              }
            }
          });
        },
        initialCameraPosition: CameraPosition(
          target: LatLng(
            TrackingScreenController.driverLocationInitialized
                ? TrackingScreenController.driverLat
                : ((r['pickupLatitude'] as num?)?.toDouble() ?? 12.9716),
            TrackingScreenController.driverLocationInitialized
                ? TrackingScreenController.driverLng
                : ((r['pickupLongitude'] as num?)?.toDouble() ?? 77.5946),
          ),
          zoom: 15.0,
        ),
        markers: markers,
        polylines: polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        tiltGesturesEnabled: true,
        rotateGesturesEnabled: true,
        style: kLightMapStyle,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  STATUS PILL
  // ═══════════════════════════════════════════════════════

  Widget _buildStatusPill(String status) {
    return ClipRRect(
      borderRadius: TrackingTokens.r32,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: TrackingTokens.r32,
            border: Border.all(
                color: Colors.white.withOpacity(0.6), width: 1),
            boxShadow: TrackingTokens.softShadow,
          ),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: TrackingTokens.statusColor(status),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: TrackingTokens.statusColor(status)
                          .withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1)
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              TrackingTokens.statusLabel(status),
              style: const TextStyle(
                  color: TrackingTokens.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2),
            ),
            const Spacer(),
            if (!wsConnected)
              const ReconnectingBadge()
            else if (status == 'ASSIGNED' ||
                status == 'ARRIVED' ||
                status == 'IN_PROGRESS')
              _buildLiveChip()
            else if (status == 'SEARCHING')
              _buildSearchingChip()
            else
              Text(
                '~${eta.toStringAsFixed(0)} min',
                style: const TextStyle(
                    color: TrackingTokens.inkMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildLiveChip() {
    final fresh = lastLocationUpdate != null &&
        DateTime.now()
                .difference(lastLocationUpdate!)
                .inSeconds <
            5;
    final color =
        fresh ? TrackingTokens.accentGreen : TrackingTokens.accentAmber;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      PulsingDot(color: color),
      const SizedBox(width: 5),
      Text(
        fresh ? 'Live' : 'Updating',
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
      ),
    ]);
  }

  Widget _buildSearchingChip() {
    final mins = searchTimeRemaining ~/ 60;
    final secs = searchTimeRemaining % 60;
    final countdown = '$mins:${secs.toString().padLeft(2, '0')}';
    final radius = searchRadiusKm.toStringAsFixed(0);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      PulsingDot(color: TrackingTokens.accentAmber),
      const SizedBox(width: 5),
      Text(
        '${radius}km · $countdown',
        style: const TextStyle(
            color: TrackingTokens.accentAmber,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
      ),
    ]);
  }

  Widget _buildSearchingCard() {
    final mins = searchTimeRemaining ~/ 60;
    final secs = searchTimeRemaining % 60;
    final countdown = '$mins:${secs.toString().padLeft(2, '0')}';
    final radius = searchRadiusKm.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrackingTokens.offWhite,
        borderRadius: TrackingTokens.r16,
        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.4)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Color(0xFFFFC107),
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Searching for your driver',
                  style: TextStyle(
                      color: TrackingTokens.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                'Cycle $searchCycle · Ring $searchRing · ${radius}km radius',
                style: const TextStyle(
                    color: TrackingTokens.inkMid, fontSize: 12),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              countdown,
              style: const TextStyle(
                  color: TrackingTokens.accentAmber,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5),
            ),
            const Text('remaining',
                style: TextStyle(
                    color: TrackingTokens.inkLight,
                    fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 12),
        // Ring progress indicator (3 rings per cycle)
        Row(children: List.generate(3, (i) {
          final active = i + 1 <= searchRing;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFFC107)
                    : TrackingTokens.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        })),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('5km', style: TextStyle(color: TrackingTokens.inkLight, fontSize: 10)),
          const Text('10km', style: TextStyle(color: TrackingTokens.inkLight, fontSize: 10)),
          const Text('15km', style: TextStyle(color: TrackingTokens.inkLight, fontSize: 10)),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  3D BADGE + MAP CONTROLS
  // ═══════════════════════════════════════════════════════

  Widget _build3DBadge() {
    return ClipRRect(
      borderRadius: TrackingTokens.r20,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: TrackingTokens.accent.withOpacity(0.85),
            borderRadius: TrackingTokens.r20,
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.threed_rotation, color: Colors.white, size: 13),
            SizedBox(width: 4),
            Text('3D',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ]),
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Column(children: [
      TrackingGlassButton(
        onTap: () {
          if (is3DMode) {
            follow3D(TrackingScreenController.driverLat,
                TrackingScreenController.driverLng,
                TrackingScreenController.driverBearing);
          } else {
            mapController?.animateCamera(CameraUpdate.newLatLng(
                LatLng(TrackingScreenController.driverLat,
                    TrackingScreenController.driverLng)));
          }
        },
        size: 44,
        child: const Icon(Icons.my_location_rounded,
            color: TrackingTokens.accentBlue, size: 20),
      ),
    ]);
  }

  double _bottomPanelEstimatedHeight(String status) {
    if (status == 'SEARCHING') return 340;
    if (status == 'ARRIVED') return 420;
    if (status == 'IN_PROGRESS') return 320;
    return 300;
  }

  // ═══════════════════════════════════════════════════════
  //  BOTTOM SHEET
  // ═══════════════════════════════════════════════════════

  Widget _buildBottomSheet(Map<String, dynamic> r, String status) {
    return AnimatedBuilder(
      animation: sheetAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 60 * (1 - sheetAnim.value)),
        child: Opacity(
            opacity: sheetAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: TrackingTokens.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, -4)),
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, -1)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TrackingTokens.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (status == 'SEARCHING') ...[
                _buildSearchingCard(),
                const SizedBox(height: 12),
              ],
              if (status == 'ARRIVED') ...[
                OtpCardWidget(
                  otp: r['pickupOtp']?.toString(),
                  otpTimeRemaining: otpTimeRemaining,
                ),
                const SizedBox(height: 12),
              ],
              if (status == 'IN_PROGRESS') ...[
                _buildFareCard(r),
                const SizedBox(height: 12),
              ],
              ProgressStepperWidget(status: status),
              const SizedBox(height: 14),
              if (status != 'SEARCHING') ...[
                DriverCardWidget(
                  ride: r,
                  cachedRideData: cachedRideData,
                  onPhoneTap: () {
                    final phone = r['driverPhone'];
                    if (phone != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Calling $phone'),
                          backgroundColor: TrackingTokens.accentBlue,
                          behavior: SnackBarBehavior.floating,
                          shape: const RoundedRectangleBorder(
                              borderRadius: TrackingTokens.r12)));
                    }
                  },
                  onChatTap: () => Navigator.pushNamed(context, '/chat',
                      arguments: {
                        'rideId': r['id']?.toString(),
                        'driverName': r['driverName'] ?? 'Driver'
                      }),
                ),
                const SizedBox(height: 12),
              ],
              if (status == 'SEARCHING' ||
                  status == 'ASSIGNED' ||
                  status == 'ARRIVED')
                _buildCancelBtn(r, status),
              if (status == 'COMPLETED') ...[
                const SizedBox(height: 4),
                _buildConfirmPaymentBtn(r),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  FARE CARD
  // ═══════════════════════════════════════════════════════

  Widget _buildFareCard(Map<String, dynamic> ride) {
    final fare = (ride['actualFare'] as num?)?.toDouble() ??
        (ride['estimatedFare'] as num?)?.toDouble() ??
        0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TrackingTokens.offWhite,
        borderRadius: TrackingTokens.r12,
        border: Border.all(color: TrackingTokens.divider),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: TrackingTokens.accentGreen.withOpacity(0.1),
              borderRadius: TrackingTokens.r8),
          child: const Icon(Icons.currency_rupee_rounded,
              color: TrackingTokens.accentGreen, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Running Fare',
              style: TextStyle(
                  color: TrackingTokens.inkLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          Text('₹${fare.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: TrackingTokens.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        ]),
        const Spacer(),
        const Text('Meter running...',
            style: TextStyle(color: TrackingTokens.inkLight, fontSize: 11)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  BUTTONS
  // ═══════════════════════════════════════════════════════

  Widget _buildCancelBtn(Map<String, dynamic> r, String status) {
    final label = switch (status) {
      'SEARCHING' => 'Cancel Booking · Free',
      'ASSIGNED'  => 'Cancel Booking · ₹50 fee',
      _           => 'Cancel Booking · Fee applies',
    };
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: () => _showCancelDialog(r, status),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.withOpacity(0.5), width: 1.2),
          shape: const RoundedRectangleBorder(
              borderRadius: TrackingTokens.r12),
          foregroundColor: Colors.red,
        ),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildConfirmPaymentBtn(Map<String, dynamic> r) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => Navigator.pushReplacementNamed(
            context, '/bill-confirmation',
            arguments: r),
        style: ElevatedButton.styleFrom(
          backgroundColor: TrackingTokens.accent,
          foregroundColor: TrackingTokens.white,
          shape: const RoundedRectangleBorder(
              borderRadius: TrackingTokens.r12),
          elevation: 0,
        ),
        child: const Text('Review Bill & Confirm Payment',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  DIALOGS
  // ═══════════════════════════════════════════════════════

  Future<void> _showCancelDialog(
      Map<String, dynamic> r, String status) async {
    final feeText = switch (status) {
      'SEARCHING' => 'No cancellation fee will be charged.',
      'ASSIGNED'  => '₹50 cancellation fee will be charged.',
      _           => 'A distance-based fee (min ₹50) applies.',
    };
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TrackingTokens.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: TrackingTokens.r20),
        title: const Text('Cancel Booking?',
            style: TextStyle(
                color: TrackingTokens.ink,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        content: Text(feeText,
            style: const TextStyle(
                color: TrackingTokens.inkMid,
                fontSize: 14,
                height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Ride',
                style: TextStyle(
                    color: TrackingTokens.inkMid,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Ride',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        final result = await ApiService.cancelRide(r['id'].toString());
        final fee = result.cancellationFee;
        if (mounted) {
          Provider.of<RideProvider>(context, listen: false).clearRide();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(fee != null && fee > 0
                ? 'Cancelled. Fee: ₹${fee.toStringAsFixed(0)}'
                : 'Cancelled. No fee charged.'),
            backgroundColor: fee != null && fee > 0
                ? TrackingTokens.accentAmber
                : TrackingTokens.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
                borderRadius: TrackingTokens.r12),
          ));
          Navigator.pushNamedAndRemoveUntil(
              context, '/home', (_) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(
                  borderRadius: TrackingTokens.r12)));
        }
      }
    }
  }

  void _showSosDialog(BuildContext ctx) {
    final ride =
        Provider.of<RideProvider>(ctx, listen: false).currentRide;
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: TrackingTokens.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: TrackingTokens.r20),
        title: const Row(children: [
          Icon(Icons.emergency_rounded, color: Colors.red, size: 22),
          SizedBox(width: 8),
          Text('Emergency SOS',
              style: TextStyle(
                  color: TrackingTokens.ink,
                  fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'This will alert emergency services and notify your emergency contacts with your current location.',
          style: TextStyle(
              color: TrackingTokens.inkMid, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    color: TrackingTokens.inkMid,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                double lat = TrackingScreenController.driverLat,
                    lng = TrackingScreenController.driverLng;
                try {
                  final pos = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.best,
                      timeLimit: const Duration(seconds: 5));
                  lat = pos.latitude;
                  lng = pos.longitude;
                } catch (_) {}
                await ApiService.triggerSOS(
                    rideId: ride?['id']?.toString(),
                    latitude: lat,
                    longitude: lng);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('SOS Sent to emergency services'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating));
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Failed to send SOS. Please call 112.'),
                      behavior: SnackBarBehavior.floating));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0),
            child: const Text('SEND SOS',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}