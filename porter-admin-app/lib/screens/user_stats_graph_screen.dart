import 'package:flutter/material.dart';
import '../widgets/graphs/bar_chart_widget.dart';
import '../widgets/graphs/donut_chart_widget.dart';

class UserStatsGraphScreen extends StatelessWidget {
  final Map<String, dynamic> detail;

  const UserStatsGraphScreen({super.key, required this.detail});

  // ── Palette (mirrors DriverDashboardScreen) ──────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _amber   = Color(0xFFFFC72C);
  static const Color _orange  = Color(0xFFFF8C42);

  @override
  Widget build(BuildContext context) {
    final d    = detail;
    final name = d['fullName'] ?? 'User';
    final avg  = (d['averageRating'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
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
          '$name — Analytics',
          style: const TextStyle(
            color: _textPri,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Summary cards ──────────────────────────────────────────────
            _SummaryGrid(items: [
              _SummaryItem('Total Rides',  '${d['totalRides'] ?? 0}',            Icons.route_rounded,          _accent),
              _SummaryItem('Total Spent',  '₹${_fmt(d['totalSpent'])}',          Icons.currency_rupee_rounded, _orange),
              _SummaryItem('Avg Rating',   avg > 0 ? avg.toStringAsFixed(2) : 'N/A', Icons.star_rounded,      _amber),
              _SummaryItem('Rated By',     '${d['totalRatings'] ?? 0} drivers',  Icons.local_taxi_rounded,     _green),
            ]),

            const SizedBox(height: 28),
            _sectionLabel('Ride Activity'),
            const SizedBox(height: 14),

            // ── Rides bar chart ────────────────────────────────────────────
            BarChartWidget(
              title: 'Rides',
              bars: [
                BarData(label: 'Today', value: _dv(d['todayRides']),  color: _accent),
                BarData(label: 'Week',  value: _dv(d['weekRides']),   color: _accent.withOpacity(0.70)),
                BarData(label: 'Month', value: _dv(d['monthRides']),  color: _accent.withOpacity(0.45)),
                BarData(label: 'All',   value: _dv(d['totalRides']),  color: _accent.withOpacity(0.20)),
              ],
            ),

            const SizedBox(height: 24),
            _sectionLabel('Spending Breakdown'),
            const SizedBox(height: 14),

            // ── Spending bar chart ─────────────────────────────────────────
            BarChartWidget(
              title: 'Spent (₹)',
              unit: '₹',
              bars: [
                BarData(label: 'Today', value: _dv(d['todaySpent']),  color: _orange),
                BarData(label: 'Week',  value: _dv(d['weekSpent']),   color: _orange.withOpacity(0.70)),
                BarData(label: 'Month', value: _dv(d['monthSpent']),  color: _orange.withOpacity(0.45)),
                BarData(label: 'All',   value: _dv(d['totalSpent']),  color: _orange.withOpacity(0.20)),
              ],
            ),

            const SizedBox(height: 24),
            _sectionLabel('Rating Distribution'),
            const SizedBox(height: 14),

            // ── Rating donut ───────────────────────────────────────────────
            _buildRatingDonut(d),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDonut(Map<String, dynamic> d) {
    final dist = d['ratingDistribution'] as Map<String, dynamic>? ?? {};
    final colors = [
      const Color(0xFF00C48C),
      const Color(0xFF8BC34A),
      const Color(0xFFFFC72C),
      const Color(0xFFFF8C42),
      const Color(0xFFFF3B30),
    ];
    final sections = List.generate(5, (i) {
      final star = 5 - i;
      return DonutSection(
        label: '$star ★',
        value: ((dist['${star}stars'] as num?)?.toDouble() ?? 0),
        color: colors[i],
      );
    }).where((s) => s.value > 0).toList();

    final avg = (d['averageRating'] as num?)?.toDouble() ?? 0.0;
    return DonutChartWidget(
      title: 'Ratings by Drivers',
      sections: sections,
      centerText: avg > 0 ? '${avg.toStringAsFixed(1)}★' : '',
    );
  }

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

  double _dv(dynamic v) => v == null ? 0.0 : (v as num).toDouble();

  String _fmt(dynamic v) {
    final d = _dv(v);
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}k';
    return d.toStringAsFixed(0);
  }
}

// ─── Summary grid ─────────────────────────────────────────────────────────

class _SummaryItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryItem(this.label, this.value, this.icon, this.color);
}

class _SummaryGrid extends StatelessWidget {
  final List<_SummaryItem> items;
  const _SummaryGrid({required this.items});

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
      children: items.map((item) => Container(
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
                borderRadius: BorderRadius.circular(10),
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
                      fontSize: 15,
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
      )).toList(),
    );
  }
}