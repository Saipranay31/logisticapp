import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─── Theme tokens — identical to HomeTabScreen & EarningsTabScreen ────────────
class _T {
  static const bg            = Color(0xFFF5F5F7);
  static const white         = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF1A1A2E);
  static const accent        = Color(0xFFFF6B35);
  static const green         = Color(0xFF00C853);
  static const red           = Color(0xFFFF3B30);
  static const amber         = Color(0xFFFFB300);
  static const purple        = Color(0xFF6C63FF);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x10000000);
  static const divider       = Color(0xFFEEEEEE);
}

class TripsTabScreen extends StatefulWidget {
  const TripsTabScreen({super.key});

  @override
  State<TripsTabScreen> createState() => _TripsTabScreenState();
}

class _TripsTabScreenState extends State<TripsTabScreen>
    with SingleTickerProviderStateMixin {

  List<dynamic>        _trips   = [];
  bool                 _loading = true;
  Map<String, dynamic> _stats   = {};
  String               _filter  = 'ALL'; // ALL | COMPLETED | CANCELLED

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _load();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final r        = await ApiService.getDriverRideHistory();
      final earnings = await ApiService.getDriverEarnings(period: 'weekly');
      print('✅ TRIPS LOADED: ${r.length} trips');
      if (mounted) {
        double totalEarnings  = 0;
        int    completedTrips = 0;
        for (final trip in r) {
          if (trip.status == 'COMPLETED') {
            completedTrips++;
            final fare = trip.actualFare ?? trip.estimatedFare;
            if (fare != null) totalEarnings += (fare as num).toDouble();
          }
        }
        setState(() {
          _trips = r is List ? r : [];
          _stats = {
            'totalTrips':     r.length,
            'completedTrips': completedTrips,
            'totalEarnings':  totalEarnings,
            'weeklyEarnings': earnings['totalEarnings'] ?? 0,
          };
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ ERROR LOADING TRIPS: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Status helpers ───────────────────────────────────────────────────────
  Color _statusColor(String status) => switch (status) {
    'COMPLETED'                    => _T.green,
    'CANCELLED'                    => _T.red,
    'IN_PROGRESS' || 'PICKED_UP'   => _T.amber,
    _                              => _T.textHint,
  };

  Color _statusBg(String status) => switch (status) {
    'COMPLETED'                    => _T.green.withValues(alpha: 0.1),
    'CANCELLED'                    => _T.red.withValues(alpha: 0.1),
    'IN_PROGRESS' || 'PICKED_UP'   => _T.amber.withValues(alpha: 0.1),
    _                              => _T.textHint.withValues(alpha: 0.1),
  };

  IconData _statusIcon(String status) => switch (status) {
    'COMPLETED'                    => Icons.check_circle_rounded,
    'CANCELLED'                    => Icons.cancel_rounded,
    'IN_PROGRESS' || 'PICKED_UP'   => Icons.local_shipping_rounded,
    _                              => Icons.info_rounded,
  };

  List<dynamic> get _filtered {
    if (_filter == 'ALL') return _trips;
    return _trips.where((t) => t.status == _filter).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _T.bg,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeader(),
                if (!_loading && _trips.isNotEmpty) ...[
                  _summaryRow(),
                  _filterBar(),
                ],
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Page header ──────────────────────────────────────────────────────────
  Widget _pageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TRIPS',
                style: TextStyle(
                    color: _T.textSecondary, fontSize: 10,
                    letterSpacing: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Trip History',
                style: TextStyle(
                    color: _T.textPrimary, fontSize: 22,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ]),
        ),
        // Total badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _T.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded, color: _T.accent, size: 14),
            const SizedBox(width: 6),
            Text('${_trips.length} total',
                style: const TextStyle(
                    color: _T.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  // ── Summary stat row ─────────────────────────────────────────────────────
  Widget _summaryRow() {
    final items = [
      (_T.green,  Icons.check_circle_outline_rounded,
          '${_stats['completedTrips'] ?? 0}',        'Completed'),
      (_T.accent, Icons.account_balance_wallet_outlined,
          '₹${(_stats['totalEarnings'] as double?)?.toStringAsFixed(0) ?? 0}', 'Earned'),
      (_T.purple, Icons.calendar_view_week_rounded,
          '₹${_stats['weeklyEarnings'] ?? 0}',       'This Week'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final (color, icon, value, label) = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: _T.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(height: 10),
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

  // ── Filter chips ─────────────────────────────────────────────────────────
  Widget _filterBar() {
    const filters = [
      ('ALL',        'All Trips'),
      ('COMPLETED',  'Completed'),
      ('CANCELLED',  'Cancelled'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final (key, label) = f;
            final active = _filter == key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _T.primary : _T.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: active
                            ? _T.primary.withValues(alpha: 0.2)
                            : _T.cardShadow,
                        blurRadius: active ? 12 : 6,
                        offset: const Offset(0, 3))],
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: active ? Colors.white : _T.textSecondary,
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────
  Widget _body() {
    if (_loading) return _loadingState();
    if (_trips.isEmpty) return _emptyState();

    final list = _filtered;
    if (list.isEmpty) return _emptyFilterState();

    return RefreshIndicator(
      onRefresh: _load,
      color: _T.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        itemCount: list.length,
        itemBuilder: (_, i) => _tripCard(list[i]),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _loadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
            color: _T.white, borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 12, offset: Offset(0, 4))]),
        child: const Center(
          child: SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _T.accent)),
        ),
      ),
      const SizedBox(height: 14),
      const Text('Loading trips…',
          style: TextStyle(color: _T.textSecondary, fontSize: 13)),
    ]),
  );

  // ── Empty states ──────────────────────────────────────────────────────────
  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            color: _T.white, borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 12, offset: Offset(0, 4))]),
        child: Icon(Icons.receipt_long_rounded,
            color: _T.textHint.withValues(alpha: 0.5), size: 32),
      ),
      const SizedBox(height: 16),
      const Text('No trips yet',
          style: TextStyle(color: _T.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Your completed deliveries will appear here',
          style: TextStyle(color: _T.textSecondary, fontSize: 13)),
    ]),
  );

  Widget _emptyFilterState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            color: _T.white, borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 12, offset: Offset(0, 4))]),
        child: const Icon(Icons.filter_list_rounded, color: _T.textHint, size: 30),
      ),
      const SizedBox(height: 16),
      const Text('No trips for this filter',
          style: TextStyle(color: _T.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => setState(() => _filter = 'ALL'),
        child: const Text('Show all trips →',
            style: TextStyle(color: _T.accent, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  // ── Trip card ─────────────────────────────────────────────────────────────
  Widget _tripCard(dynamic t) {
    final status   = t.status as String;
    final fare     = t.actualFare ?? t.estimatedFare;
    final date     = t.createdAt.toString().substring(0, 10);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        // ── Top bar: status + fare ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _statusBg(status),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Icon(_statusIcon(status), color: _statusColor(status), size: 15),
            const SizedBox(width: 6),
            Text(
              status.replaceAll('_', ' '),
              style: TextStyle(
                  color: _statusColor(status),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4),
            ),
            const Spacer(),
            // Fare pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _T.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('₹$fare',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // ── Route ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Pickup
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: _T.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.pickupAddress ?? 'Pickup',
                  style: const TextStyle(
                      color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            // Dashed connector
            Padding(
              padding: const EdgeInsets.only(left: 3.5),
              child: Column(children: List.generate(3, (_) => Container(
                width: 1, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                color: _T.divider,
              ))),
            ),
            // Drop
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _T.accent, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.dropAddress ?? 'Drop',
                  style: const TextStyle(
                      color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),

            const SizedBox(height: 12),
            const Divider(color: _T.divider, height: 1),
            const SizedBox(height: 10),

            // ── Footer: date + payment tag ──────────────────────────
            Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  color: _T.textHint, size: 12),
              const SizedBox(width: 4),
              Text(date,
                  style: const TextStyle(color: _T.textSecondary, fontSize: 11)),
              const Spacer(),
              if (t.paymentMethod != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _T.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.payments_outlined, color: _T.textSecondary, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      '${t.paymentMethod}'.replaceAll('_', ' '),
                      style: const TextStyle(
                          color: _T.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}