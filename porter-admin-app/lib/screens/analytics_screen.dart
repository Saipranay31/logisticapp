import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'analytics_graph_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _blue    = Color(0xFF0066FF);
  static const Color _teal    = Color(0xFF00B4D8);
  static const Color _orange  = Color(0xFFFF8C42);
  static const Color _violet  = Color(0xFF7B61FF);

  Map<String, dynamic>? _revenue;
  Map<String, dynamic>? _drivers;
  Map<String, dynamic>? _users;
  Map<String, dynamic>? _payments;
  Map<String, dynamic>? _support;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getRevenueAnalytics(),
        ApiService.getDriversOverview(),
        ApiService.getUserAnalytics(),
        ApiService.getPaymentAnalytics(),
        ApiService.getSupportAnalytics(),
      ]);
      setState(() {
        _revenue  = results[0]['data'];
        _drivers  = results[1]['data'];
        _users    = results[2]['data'];
        _payments = results[3]['data'];
        _support  = results[4]['data'];
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              color: _accent,
              backgroundColor: _surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryBanner(),
                    const SizedBox(height: 28),
                    _section(
                      title: 'Revenue',
                      icon: Icons.currency_rupee_rounded,
                      iconColor: _green,
                      iconBg: _green.withOpacity(0.10),
                      child: _revenueSection(),
                    ),
                    const SizedBox(height: 20),
                    _section(
                      title: 'Drivers',
                      icon: Icons.drive_eta_rounded,
                      iconColor: _blue,
                      iconBg: _blue.withOpacity(0.10),
                      child: _driversSection(),
                    ),
                    const SizedBox(height: 20),
                    _section(
                      title: 'Users',
                      icon: Icons.people_rounded,
                      iconColor: _teal,
                      iconBg: _teal.withOpacity(0.10),
                      child: _usersSection(),
                    ),
                    const SizedBox(height: 20),
                    _section(
                      title: 'Payments',
                      icon: Icons.payment_rounded,
                      iconColor: _orange,
                      iconBg: _orange.withOpacity(0.10),
                      child: _paymentsSection(),
                    ),
                    const SizedBox(height: 20),
                    _section(
                      title: 'Support',
                      icon: Icons.support_agent_rounded,
                      iconColor: _violet,
                      iconBg: _violet.withOpacity(0.10),
                      child: _supportSection(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
      title: const Text(
        'Analytics',
        style: TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded, color: _textSec),
          tooltip: 'View Graphs',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalyticsGraphScreen(
                revenue: _revenue,
                drivers: _drivers,
                users: _users,
                payments: _payments,
                support: _support,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textSec),
          onPressed: _load,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUMMARY BANNER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _summaryBanner() {
    return Container(
      width: double.infinity,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Summary',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_revenue?['totalRevenue'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total Revenue',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bannerPill('${_revenue?['totalRides'] ?? 0} rides', const Color(0xFF00C48C)),
              const SizedBox(height: 8),
              _bannerPill('${_revenue?['completionRate'] ?? 0}% completion', _accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION WRAPPER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _section({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: _textPri,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVENUE SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _revenueSection() {
    return Column(
      children: [
        // Highlight row
        Row(
          children: [
            _highlightTile('Avg Fare', '₹${_revenue?['averageFare'] ?? 0}', _green),
            const SizedBox(width: 10),
            _highlightTile('Commission', '₹${_revenue?['platformCommission'] ?? 0}', _blue),
            const SizedBox(width: 10),
            _highlightTile('Driver Pay', '₹${_revenue?['driverPayout'] ?? 0}', _violet),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: _border, height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            _statTile('Total Rides', '${_revenue?['totalRides'] ?? 0}'),
            _divider(),
            _statTile('Completion', '${_revenue?['completionRate'] ?? 0}%'),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DRIVERS SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _driversSection() {
    final total    = (_drivers?['totalDrivers'] ?? 0) as num;
    final verified = (_drivers?['verifiedDrivers'] ?? 0) as num;
    final verPct   = total > 0 ? (verified / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _statTile('Total', '${_drivers?['totalDrivers'] ?? 0}'),
            _divider(),
            _statTile('Online Now', '${_drivers?['onlineNow'] ?? 0}'),
            _divider(),
            _statTile('Verified', '${_drivers?['verifiedDrivers'] ?? 0}'),
            _divider(),
            _statTile('Pending KYC', '${_drivers?['pendingKyc'] ?? 0}'),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: _border, height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text('Verification rate', style: TextStyle(color: _textSec, fontSize: 12)),
            const Spacer(),
            Text(
              '${(verPct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: _textPri, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: verPct.toDouble(),
            minHeight: 7,
            backgroundColor: _border,
            valueColor: const AlwaysStoppedAnimation<Color>(_blue),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USERS SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _usersSection() {
    return Row(
      children: [
        _highlightTile('Total Users', '${_users?['totalUsers'] ?? 0}', _teal),
        const SizedBox(width: 12),
        _highlightTile('New This Week', '${_users?['newThisWeek'] ?? 0}', _accent),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENTS SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _paymentsSection() {
    final total   = (_payments?['totalPayments'] ?? 0) as num;
    final success = (_payments?['successfulPayments'] ?? 0) as num;
    final failed  = (_payments?['failedPayments'] ?? 0) as num;
    final sucPct  = total > 0 ? (success / total) : 0.0;
    final failPct = total > 0 ? (failed / total) : 0.0;

    return Column(
      children: [
        Row(
          children: [
            _statTile('Total', '$total'),
            _divider(),
            _statTile('Success', '$success'),
            _divider(),
            _statTile('Failed', '$failed'),
            _divider(),
            _statTile('Pending', '${_payments?['pendingPayments'] ?? 0}'),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: _border, height: 1),
        const SizedBox(height: 14),
        // Processed amount highlight
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _orange.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.payments_rounded, color: _orange, size: 18),
              const SizedBox(width: 10),
              const Text('Total Processed', style: TextStyle(color: _textSec, fontSize: 12)),
              const Spacer(),
              Text(
                '₹${_payments?['totalProcessedAmount'] ?? 0}',
                style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Success / failure rate bars
        _labeledBar('Success Rate', sucPct.toDouble(), _green, '${_payments?['successRate'] ?? 0}%'),
        const SizedBox(height: 8),
        _labeledBar('Failure Rate', failPct.toDouble(), const Color(0xFFFF3B30), '${(failPct * 100).toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _labeledBar(String label, double value, Color color, String pctLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: _textSec, fontSize: 12)),
            const Spacer(),
            Text(pctLabel, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUPPORT SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _supportSection() {
    final total    = (_support?['totalTickets'] ?? 0) as num;
    final resolved = (_support?['resolvedTickets'] ?? 0) as num;
    final resPct   = total > 0 ? (resolved / total) : 0.0;

    return Column(
      children: [
        Row(
          children: [
            _statTile('Total', '$total'),
            _divider(),
            _statTile('Open', '${_support?['openTickets'] ?? 0}'),
            _divider(),
            _statTile('In Progress', '${_support?['inProgressTickets'] ?? 0}'),
            _divider(),
            _statTile('Resolved', '$resolved'),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: _border, height: 1),
        const SizedBox(height: 14),
        _labeledBar('Resolution Rate', resPct.toDouble(), _violet, '${_support?['resolutionRate'] ?? 0}%'),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Tall coloured highlight tile — used for monetary or important values
  Widget _highlightTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: _textSec, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// Plain inline stat — label + value in a flex row
  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _textPri,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: _textSec, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: _border);
}