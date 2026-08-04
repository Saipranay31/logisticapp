import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
// ─── Theme tokens (matches user home screen palette) ─────────────────────────
class _T {
  static const bg            = Color(0xFFF5F5F7);
  static const white         = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF1A1A2E);
  static const accent        = Color(0xFFFF6B35);
  static const green         = Color(0xFF00C853);
  static const red           = Color(0xFFFF3B30);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x10000000);
  static const divider       = Color(0xFFEEEEEE);
}

class HomeTabScreen extends StatefulWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;

  const HomeTabScreen({
    super.key,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen>
    with SingleTickerProviderStateMixin {

  // ─── State — 100% original, untouched ────────────────────────────────────
  Map<String, dynamic> _stats     = {};
  List<dynamic>        _activeRides = [];
  bool                 _loadingStats = true;

  // ─── Entrance animation ───────────────────────────────────────────────────
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;
bool _sosSending = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _loadData();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // ─── didUpdateWidget — original fix preserved ─────────────────────────────
  @override
  void didUpdateWidget(HomeTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline) _loadData();
  }

  // ─── _loadData — original logic, not a single line changed ───────────────
  Future<void> _loadData() async {
    try {
      final earnings = await ApiService.getDriverEarnings(period: 'daily');
      final profile  = await ApiService.getDriverProfile();
      if (mounted) {
        print('📊 HOME: Earnings data: $earnings');
        print('📊 HOME: Profile rating: ${profile.rating}, totalRides: ${profile.totalRides}');

        final earningsData =
            (earnings['data'] ?? earnings) as Map<String, dynamic>? ?? earnings;

       setState(() {
  _stats = {
    'rating': profile.rating != null
        ? profile.rating!.toStringAsFixed(1)
        : '0.0',
    'todayEarnings': '₹${earningsData['totalEarnings'] ?? earningsData['todayEarnings'] ?? 0}',
    'todayTrips': '${earningsData['totalRides'] ?? earningsData['todayTrips'] ?? profile.totalRides}',
  };
  _loadingStats = false;
});
      }
    } catch (e) {
      print('❌ HOME: Error loading stats: $e');
      if (mounted) {
        setState(() {
          _stats = {'rating': '0.0', 'todayEarnings': '₹0', 'todayTrips': '0'};
          _loadingStats = false;
        });
      }
    }

    if (mounted) setState(() => _activeRides = []);
  }
Future<Position?> _getLiveLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }
  if (permission == LocationPermission.deniedForever) return null;

  return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
}


  // ═════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final auth      = Provider.of<AuthProvider>(context);
    final firstName = (auth.fullName ?? 'Driver').split(' ').first;
    final hour      = DateTime.now().hour;
    final greeting  = hour < 12 ? 'Good Morning'
                    : hour < 17 ? 'Good Afternoon'
                    : 'Good Evening';

    return ColoredBox(
      color: _T.bg,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: _T.accent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header(greeting, firstName)),
                  SliverToBoxAdapter(child: _onlineCard()),
                  SliverToBoxAdapter(child: _statsRow()),
                  SliverToBoxAdapter(child: _quickActions()),
                  SliverToBoxAdapter(child: _tripsSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _header(String greeting, String firstName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting,
                  style: const TextStyle(
                      color: _T.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('$firstName 👋',
                  style: const TextStyle(
                      color: _T.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6)),
              const SizedBox(height: 3),
              const Text('Ready to earn today?',
                  style: TextStyle(color: _T.textSecondary, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 12),
          // SOS button
          GestureDetector(
           onTap: () async {
  setState(() => _sosSending = true);
  try {
    final pos = await _getLiveLocation();
    if (pos == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Could not get location'), backgroundColor: _T.red));
      return;
    }
    await ApiService.triggerSOS(latitude: pos.latitude, longitude: pos.longitude);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🚨 SOS Alert Sent!'), backgroundColor: _T.red));
  } catch (_) {} finally {
    if (mounted) setState(() => _sosSending = false);
  }
},
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _T.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _T.red.withValues(alpha: 0.18)),
                boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
              ),
             // CHANGE TO
child: _sosSending
    ? const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: _T.red))
    : const Icon(Icons.sos_rounded, color: _T.red, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Online/Offline card ──────────────────────────────────────────────────
  Widget _onlineCard() {
    final on = widget.isOnline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: on ? _T.primary : _T.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: on
                ? _T.primary.withValues(alpha: 0.26)
                : _T.cardShadow,
            blurRadius: 24, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        // Icon badge
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: on
                ? _T.green.withValues(alpha: 0.15)
                : _T.textHint.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            on ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: on ? _T.green : _T.textHint, size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              on ? 'You\'re Online' : 'You\'re Offline',
              style: TextStyle(
                  color: on ? _T.white : _T.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              on ? 'Receiving trip requests' : 'Toggle to start earning',
              style: TextStyle(
                  color: on
                      ? Colors.white.withValues(alpha: 0.5)
                      : _T.textSecondary,
                  fontSize: 12),
            ),
          ]),
        ),
        // Switch — original onChanged callback preserved
        Transform.scale(
          scale: 1.05,
          child: Switch(
            value: widget.isOnline,
            onChanged: widget.onToggle,           // ← original callback
            activeColor: _T.green,
            activeTrackColor: _T.green.withValues(alpha: 0.28),
            inactiveThumbColor: _T.textHint,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.18),
          ),
        ),
      ]),
    );
  }

  // ─── Stats row ─────────────────────────────────────────────────────────────
  Widget _statsRow() {
    if (_loadingStats) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: List.generate(3, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: _T.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: const Center(child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _T.accent),
              )),
            ),
          ),
        ))),
      );
    }

    final items = [
      ('⭐', _stats['rating'] ?? '0.0', 'Rating'),
      ('💰', _stats['todayEarnings'] ?? '₹0', 'Today'),
      ('🚚', _stats['todayTrips'] ?? '0', 'Trips'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final (emoji, value, label) = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _T.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
                ),
                child: Column(children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 5),
                  Text(value,
                      style: const TextStyle(
                          color: _T.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(color: _T.textSecondary, fontSize: 10)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Quick actions ─────────────────────────────────────────────────────────
  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('QUICK ACTIONS',
            style: TextStyle(
                color: _T.textSecondary,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          _actionCard(Icons.support_agent_rounded, 'Support', '24/7 help',
              const Color(0xFF6C63FF),
              () => Navigator.pushNamed(context, '/support')),
          const SizedBox(width: 12),
          _actionCard(Icons.verified_user_rounded, 'KYC', 'Documents',
              _T.accent,
              () => Navigator.pushNamed(context, '/kyc')),
        ]),
      ]),
    );
  }

  Widget _actionCard(IconData icon, String label, String sub, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: _T.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(color: _T.textSecondary, fontSize: 11)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: _T.textHint, size: 17),
          ]),
        ),
      ),
    );
  }

  // ─── Trips section ─────────────────────────────────────────────────────────
  Widget _tripsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Row(children: [
          const Text('AVAILABLE TRIPS',
              style: TextStyle(
                  color: _T.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          if (widget.isOnline && _activeRides.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _T.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _T.green.withValues(alpha: 0.2)),
              ),
              child: Text('${_activeRides.length} new',
                  style: const TextStyle(
                      color: _T.green, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 10),

        if (!widget.isOnline) _offlineCard()
        else if (_activeRides.isEmpty) _emptyCard()
        else ..._activeRides.map((ride) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tripCard(
                context,
                '${ride['pickupAddress'] ?? 'Pickup'} → ${ride['dropAddress'] ?? 'Drop'}',
                '${ride['estimatedDistance'] ?? '?'} km',
                '₹${ride['estimatedFare'] ?? ride['fare'] ?? '?'}',
                ride['id']?.toString() ?? '',
              ),
            )),
      ]),
    );
  }

  Widget _offlineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            color: _T.textHint.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, color: _T.textHint, size: 28),
        ),
        const SizedBox(height: 14),
        const Text('You\'re Offline',
            style: TextStyle(
                color: _T.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Toggle the switch above to\nreceive trip requests',
            textAlign: TextAlign.center,
            style: TextStyle(color: _T.textSecondary, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            color: _T.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: const Icon(Icons.local_shipping_outlined, color: _T.accent, size: 28),
        ),
        const SizedBox(height: 14),
        const Text('No Trips Available',
            style: TextStyle(
                color: _T.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Hang tight! New requests\nwill appear here automatically',
            textAlign: TextAlign.center,
            style: TextStyle(color: _T.textSecondary, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  // ─── Trip card ─────────────────────────────────────────────────────────────
  Widget _tripCard(BuildContext ctx, String route, String dist, String fare, String rideId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Route with green dot
        Row(children: [
          Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: _T.green, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(route,
                style: const TextStyle(
                    color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(color: _T.divider, height: 1),
        const SizedBox(height: 12),
        // Chips + accept button
        Row(children: [
          _chip(Icons.straighten_rounded, dist),
          const SizedBox(width: 8),
          _chip(Icons.currency_rupee_rounded, fare),
          const Spacer(),
          // Accept — original onPressed logic preserved
          GestureDetector(
            onTap: () async {
              try {
                final rideProvider =
                    Provider.of<RideProvider>(context, listen: false);
                await rideProvider.acceptRide(rideId);     // ← original
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('✅ Ride accepted!'),
                        duration: Duration(seconds: 1)),
                  );
                  Navigator.pushNamed(ctx, '/active-delivery'); // ← original
                }
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: _T.red));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: _T.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: _T.primary.withValues(alpha: 0.22),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: const Text('Accept',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, color: _T.textSecondary, size: 13),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: _T.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}