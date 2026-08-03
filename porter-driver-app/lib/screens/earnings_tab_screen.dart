import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─── Theme tokens — identical to HomeTabScreen ────────────────────────────────
class _T {
  static const bg            = Color(0xFFF5F5F7);
  static const white         = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF1A1A2E);
  static const accent        = Color(0xFFFF6B35);
  static const green         = Color(0xFF00C853);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x10000000);
  static const divider       = Color(0xFFEEEEEE);
  static const purple        = Color(0xFF6C63FF);
}

class EarningsTabScreen extends StatefulWidget {
  const EarningsTabScreen({super.key});

  @override
  State<EarningsTabScreen> createState() => _EarningsTabScreenState();
}

class _EarningsTabScreenState extends State<EarningsTabScreen>
    with SingleTickerProviderStateMixin {

  Map<String, dynamic> _daily  = {};
  Map<String, dynamic> _weekly = {};
  bool _loading = true;

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
      final d = await ApiService.getDriverEarnings(period: 'daily');
      final w = await ApiService.getDriverEarnings(period: 'weekly');
      if (mounted) {
        setState(() {
          _daily  = (d['data'] ?? d) as Map<String, dynamic>? ?? {};
          _weekly = (w['data'] ?? w) as Map<String, dynamic>? ?? {};
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
            child: RefreshIndicator(
              onRefresh: _load,
              color: _T.accent,
              child: _loading ? _skeleton() : _body(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading skeleton ─────────────────────────────────────────────────────
  Widget _skeleton() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _sBox(height: 28, width: 160, radius: 8),
        const SizedBox(height: 20),
        _sBox(height: 180, width: double.infinity, radius: 24),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _sBox(height: 88, radius: 16)),
          const SizedBox(width: 12),
          Expanded(child: _sBox(height: 88, radius: 16)),
          const SizedBox(width: 12),
          Expanded(child: _sBox(height: 88, radius: 16)),
        ]),
        const SizedBox(height: 14),
        _sBox(height: 260, width: double.infinity, radius: 20),
      ]),
    );
  }

  Widget _sBox({required double height, double? width, double radius = 8}) =>
      Container(
        width: width, height: height,
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 8, offset: Offset(0, 2))],
        ),
      );

  // ── Main body ────────────────────────────────────────────────────────────
  Widget _body() {
    final todayTotal     = _daily['totalEarnings']   ?? 0;
    final todayRides     = _daily['totalRides']       ?? 0;
    final weekTotal      = _weekly['totalEarnings']  ?? 0;
    final weekRides      = _weekly['totalRides']      ?? 0;
    final avgPerRide     = _weekly['averagePerRide'] ?? 0;
    final dailyBreakdown = _weekly['dailyBreakdown'] as Map<String, dynamic>? ?? {};

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _pageHeader()),
        SliverToBoxAdapter(child: _heroCard(todayTotal, todayRides, avgPerRide)),
        SliverToBoxAdapter(child: _summaryRow(weekTotal, weekRides, avgPerRide)),
        SliverToBoxAdapter(child: _weeklyCard(dailyBreakdown, weekTotal, weekRides)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Page header ──────────────────────────────────────────────────────────
  Widget _pageHeader() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = '${now.day} ${months[now.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('EARNINGS',
                style: TextStyle(
                    color: _T.textSecondary, fontSize: 10,
                    letterSpacing: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Your Dashboard',
                style: TextStyle(
                    color: _T.textPrimary, fontSize: 22,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _T.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: _T.accent, size: 14),
            const SizedBox(width: 6),
            Text(dateLabel,
                style: const TextStyle(
                    color: _T.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  // ── Hero card ────────────────────────────────────────────────────────────
  Widget _heroCard(dynamic todayTotal, dynamic todayRides, dynamic avgPerRide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _T.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: _T.primary.withValues(alpha: 0.28),
                blurRadius: 28, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text("TODAY'S EARNINGS",
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _T.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _T.green.withValues(alpha: 0.25)),
              ),
              child: const Row(children: [
                Icon(Icons.trending_up_rounded, color: _T.green, size: 12),
                SizedBox(width: 4),
                Text('Live', style: TextStyle(color: _T.green, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),

          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹$todayTotal',
                style: const TextStyle(
                    color: Colors.white, fontSize: 44,
                    fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('today',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35), fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 22),

          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 18),

          Row(children: [
            _heroStat(Icons.local_shipping_outlined, '$todayRides', 'Trips Today'),
            _vDivider(),
            _heroStat(Icons.account_balance_wallet_outlined, '₹$avgPerRide', 'Avg / Trip'),
            _vDivider(),
            _heroStat(Icons.access_time_rounded, _estHours(todayRides), 'Est. Hours'),
          ]),
        ]),
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) => Expanded(
    child: Column(children: [
      Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 16),
      const SizedBox(height: 6),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
    ]),
  );

  Widget _vDivider() =>
      Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.1));

  String _estHours(dynamic rides) {
    final r = rides is int ? rides : int.tryParse('$rides') ?? 0;
    final mins = r * 40;
    if (mins < 60) return '${mins}m';
    return '${(mins / 60).toStringAsFixed(1)}h';
  }

  // ── 3-stat summary row ───────────────────────────────────────────────────
  Widget _summaryRow(dynamic weekTotal, dynamic weekRides, dynamic avgPerRide) {
    final items = [
      (_T.accent,  Icons.calendar_view_week_rounded,   '₹$weekTotal', 'This Week'),
      (_T.green,   Icons.check_circle_outline_rounded, '$weekRides',  'Total Rides'),
      (_T.purple,  Icons.speed_rounded,                '₹$avgPerRide','Avg/Ride'),
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

  // ── Weekly breakdown card ────────────────────────────────────────────────
  Widget _weeklyCard(Map<String, dynamic> breakdown, dynamic weekTotal, dynamic weekRides) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WEEKLY BREAKDOWN',
                    style: TextStyle(
                        color: _T.textSecondary, fontSize: 10,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Day by day earnings',
                    style: TextStyle(
                        color: _T.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: _T.bg, borderRadius: BorderRadius.circular(10)),
              child: Text('$weekRides rides',
                  style: const TextStyle(
                      color: _T.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 18),

          if (breakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Column(children: [
                  Icon(Icons.bar_chart_rounded,
                      color: _T.textHint.withValues(alpha: 0.5), size: 36),
                  const SizedBox(height: 8),
                  const Text('No earnings data yet',
                      style: TextStyle(color: _T.textSecondary, fontSize: 13)),
                ]),
              ),
            )
          else ...[
            _barChart(breakdown),
            const SizedBox(height: 18),
            const Divider(color: _T.divider, height: 1),
            const SizedBox(height: 14),
            ...breakdown.entries.map((e) => _dayRow(e.key, e.value, breakdown)),
            const SizedBox(height: 6),
            const Divider(color: _T.divider, height: 1),
            const SizedBox(height: 14),
          ],

          // Footer total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: _T.primary, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('Week Total',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('₹$weekTotal',
                  style: const TextStyle(
                      color: _T.accent, fontSize: 18,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Mini bar chart ───────────────────────────────────────────────────────
  Widget _barChart(Map<String, dynamic> breakdown) {
    double maxVal = 1;
    for (final v in breakdown.values) {
      final n = double.tryParse('$v') ?? 0;
      if (n > maxVal) maxVal = n;
    }

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: breakdown.entries.map((e) {
          final val = double.tryParse('${e.value}') ?? 0;
          final ratio = (val / maxVal).clamp(0.0, 1.0);
          final isToday = _isToday(e.key);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: ratio > 0 ? 52 * ratio + 6 : 4,
                    decoration: BoxDecoration(
                      color: isToday
                          ? _T.accent
                          : _T.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(_short(e.key),
                      style: TextStyle(
                          color: isToday ? _T.accent : _T.textHint,
                          fontSize: 9,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Day progress row ─────────────────────────────────────────────────────
  Widget _dayRow(String day, dynamic value, Map<String, dynamic> breakdown) {
    double maxVal = 1;
    for (final v in breakdown.values) {
      final n = double.tryParse('$v') ?? 0;
      if (n > maxVal) maxVal = n;
    }
    final val = double.tryParse('$value') ?? 0;
    final ratio = (val / maxVal).clamp(0.0, 1.0);
    final isToday = _isToday(day);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
          width: 32,
          child: Text(_short(day),
              style: TextStyle(
                  color: isToday ? _T.accent : _T.textSecondary,
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 8, color: _T.bg),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isToday ? _T.accent : _T.accent.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 58,
          child: Text('₹$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: isToday ? _T.textPrimary : _T.textSecondary,
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
        ),
      ]),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _short(String day) {
  try {
    final date = DateTime.parse(day);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  } catch (_) {
    return day.length >= 3 ? day.substring(0, 3).toUpperCase() : day.toUpperCase();
  }
}

bool _isToday(String day) {
  try {
    final date = DateTime.parse(day);
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  } catch (_) {
    return false;
  }
}
    }