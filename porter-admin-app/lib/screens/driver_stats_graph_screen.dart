import 'package:flutter/material.dart';
import '../widgets/graphs/bar_chart_widget.dart';
import '../widgets/graphs/donut_chart_widget.dart';

class DriverStatsGraphScreen extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const DriverStatsGraphScreen({super.key, required this.analytics});

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _amber   = Color(0xFFFFC72C);
  static const Color _blue    = Color(0xFF00B4D8);

  @override
  Widget build(BuildContext context) {
    final a    = analytics;
    final name = a['fullName'] ?? 'Driver';
    final avg  = (a['rating'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context, name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Driver identity banner ─────────────────────────────────
            _identityBanner(a, avg),
            const SizedBox(height: 28),

            // ── Summary grid ───────────────────────────────────────────
            _sectionLabel('Performance Summary'),
            const SizedBox(height: 14),
            _SummaryRow(items: [
              _SummaryItem('Total Rides',    '${a['totalRides'] ?? 0}',          Icons.directions_car_rounded,  _accent),
              _SummaryItem('Total Earnings', '₹${_fmt(a['totalEarnings'])}',     Icons.currency_rupee_rounded,  _green),
              _SummaryItem('Avg Rating',     avg.toStringAsFixed(2),             Icons.star_rounded,             _amber),
              _SummaryItem('Rated By',       '${a['totalRatings'] ?? 0} users',  Icons.people_rounded,           _blue),
            ]),
            const SizedBox(height: 28),

            // ── Rides chart ────────────────────────────────────────────
            _sectionLabel('Rides Breakdown'),
            const SizedBox(height: 14),
            _chartCard(
              child: BarChartWidget(
                title: '',
                bars: [
                  BarData(label: 'Today', value: _d(a['todayRides']),  color: _accent),
                  BarData(label: 'Week',  value: _d(a['weekRides']),   color: _accent.withOpacity(0.70)),
                  BarData(label: 'Month', value: _d(a['monthRides']),  color: _accent.withOpacity(0.45)),
                  BarData(label: 'All',   value: _d(a['totalRides']),  color: _accent.withOpacity(0.20)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Earnings chart ─────────────────────────────────────────
            _sectionLabel('Earnings Breakdown'),
            const SizedBox(height: 14),
            _chartCard(
              child: BarChartWidget(
                title: '',
                unit: '₹',
                bars: [
                  BarData(label: 'Today', value: _d(a['todayEarnings']),  color: _green),
                  BarData(label: 'Week',  value: _d(a['weekEarnings']),   color: _green.withOpacity(0.70)),
                  BarData(label: 'Month', value: _d(a['monthEarnings']),  color: _green.withOpacity(0.45)),
                  BarData(label: 'All',   value: _d(a['totalEarnings']),  color: _green.withOpacity(0.20)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Rating donut ───────────────────────────────────────────
            _sectionLabel('Rating Distribution'),
            const SizedBox(height: 14),
            _chartCard(child: _buildRatingDonut(a)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(BuildContext context, String name) {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '$name — Stats',
        style: const TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IDENTITY BANNER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _identityBanner(Map<String, dynamic> a, double avg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _primary.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          // Avatar initial
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.20),
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withOpacity(0.35), width: 2),
            ),
            child: Center(
              child: Text(
                ((a['fullName'] ?? 'D') as String)[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['fullName'] ?? 'Driver',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  a['phone'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          // Rating pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: _amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(color: _amber, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${a['totalRatings'] ?? 0} ratings',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DONUT — RATING DISTRIBUTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRatingDonut(Map<String, dynamic> a) {
    final dist = a['ratingDistribution'] as Map<String, dynamic>? ?? {};
    const colors = [
      Color(0xFF00C48C), // 5 ★
      Color(0xFF4CAF50), // 4 ★
      Color(0xFFFFC72C), // 3 ★
      Color(0xFFFF8C42), // 2 ★
      Color(0xFFFF3B30), // 1 ★
    ];
    final sections = List.generate(5, (i) {
      final star = 5 - i;
      return DonutSection(
        label: '$star ★',
        value: (dist['${star}stars'] as num?)?.toDouble() ?? 0,
        color: colors[i],
      );
    }).where((s) => s.value > 0).toList();

    final avg = (a['rating'] as num?)?.toDouble() ?? 0.0;
    return DonutChartWidget(
      title: '',
      sections: sections,
      centerText: avg > 0 ? '${avg.toStringAsFixed(1)}★' : '',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textPri,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _chartCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  double _d(dynamic v) => v == null ? 0.0 : (v as num).toDouble();

  String _fmt(dynamic v) {
    final d = _d(v);
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}k';
    return d.toStringAsFixed(0);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUMMARY ROW WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryItem(this.label, this.value, this.icon, this.color);
}

class _SummaryRow extends StatelessWidget {
  final List<_SummaryItem> items;
  const _SummaryRow({required this.items});

  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, color: item.color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.value,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.label,
                      style: const TextStyle(color: _textSec, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}