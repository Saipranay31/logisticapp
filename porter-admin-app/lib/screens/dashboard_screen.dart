import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg         = Color(0xFFF7F8FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _primary    = Color(0xFF1A1A2E);   // deep navy
  static const Color _accent     = Color(0xFF0066FF);   // corporate blue
  static const Color _border     = Color(0xFFE8ECF0);
  static const Color _textPri    = Color(0xFF0D0D0D);
  static const Color _textSec    = Color(0xFF8A94A6);

  // ── Metric colours ────────────────────────────────────────────────────────
  static const Color _green  = Color(0xFF00C48C);
  static const Color _blue   = Color(0xFF0066FF);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _violet = Color(0xFF7B61FF);
  static const Color _teal   = Color(0xFF00B4D8);
  static const Color _amber  = Color(0xFFFFC72C);

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => Provider.of<AdminProvider>(context, listen: false).fetchDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      drawer: _buildDrawer(context),
      body: Consumer<AdminProvider>(
        builder: (_, admin, __) {
          final d = admin.dashboard;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting banner ───────────────────────────────────────
                _greetingBanner(),
                const SizedBox(height: 28),

                // ── Primary KPI grid ──────────────────────────────────────
                _sectionLabel('Key Metrics'),
                const SizedBox(height: 14),
                _kpiGrid(d),
                const SizedBox(height: 28),

                // ── Platform overview ─────────────────────────────────────
                _sectionLabel('Platform Overview'),
                const SizedBox(height: 14),
                _overviewRow(d),
                const SizedBox(height: 28),

                // ── Quick actions ─────────────────────────────────────────
                _sectionLabel('Quick Actions'),
                const SizedBox(height: 14),
                _quickActions(context),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: _primary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'Porter Admin',
            style: TextStyle(
              color: _textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: _primary),
              onPressed: () {},
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () async {
            await Provider.of<AdminProvider>(context, listen: false).logout();
            if (mounted) Navigator.pushReplacementNamed(context, '/');
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD5D0)),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DRAWER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Porter Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Management Portal',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _drawerGroup('MAIN'),
                _drawerItem(context, Icons.dashboard_rounded, 'Dashboard',
                    () => Navigator.pop(context), active: true),
                _drawerItem(context, Icons.drive_eta_rounded, 'Drivers', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/drivers');
                }),
                _drawerItem(context, Icons.people_rounded, 'Users', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/users');
                }),
                _drawerItem(context, Icons.receipt_long_rounded, 'Active Orders',
                    () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/orders');
                }),
                const SizedBox(height: 8),
                _drawerGroup('SUPPORT'),
                _drawerItem(
                    context, Icons.support_agent_rounded, 'Support Tickets', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/tickets');
                }),
                _drawerItem(context, Icons.payments_rounded, 'Payouts', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/payouts');
                }),
                _drawerItem(context, Icons.gavel_rounded, 'Disputes', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/disputes');
                }),
                _drawerItem(context, Icons.emergency_rounded, 'Emergency Alerts',
                    () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/alerts');
                }),
                const SizedBox(height: 8),
                _drawerGroup('INSIGHTS'),
                _drawerItem(context, Icons.analytics_rounded, 'Analytics', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/analytics');
                }),
                _drawerItem(
                    context, Icons.batch_prediction_rounded, 'Batch Ops', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/batch');
                }),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: _textSec, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin User',
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('Super Admin',
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerGroup(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: _textSec,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? _accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            color: active ? _accent : _textSec,
            size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: active ? _accent : _textPri,
          fontSize: 14,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: active ? _accent.withOpacity(0.05) : Colors.transparent,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GREETING
  // ══════════════════════════════════════════════════════════════════════════
  Widget _greetingBanner() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, Admin 👋',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Here\'s what\'s happening today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '● Live',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

  // ══════════════════════════════════════════════════════════════════════════
  // KPI GRID  (2 × 3)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _kpiGrid(Map<String, dynamic>? d) {
    final metrics = [
      _MetricData('Active Drivers', '${d?['activeDrivers'] ?? 0}',
          Icons.drive_eta_rounded, _green, '+12%'),
      _MetricData('Total Users', '${d?['totalUsers'] ?? 0}',
          Icons.people_rounded, _blue, '+8%'),
      _MetricData('Today\'s Rides', '${d?['todayRides'] ?? 0}',
          Icons.receipt_long_rounded, _orange, '+5%'),
      _MetricData(
          'Total Revenue',
          '₹${((d?['totalRevenue'] ?? 0) as num).toStringAsFixed(0)}',
          Icons.currency_rupee_rounded,
          _violet,
          '+18%'),
      _MetricData('Completed', '${d?['completedRides'] ?? 0}',
          Icons.check_circle_rounded, _teal, '+3%'),
      _MetricData(
          'Today Revenue',
          '₹${((d?['todayRevenue'] ?? 0) as num).toStringAsFixed(0)}',
          Icons.trending_up_rounded,
          _amber,
          '+22%'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: metrics.length,
      itemBuilder: (_, i) => _kpiCard(metrics[i]),
    );
  }

  Widget _kpiCard(_MetricData m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: m.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(m.icon, color: m.color, size: 17),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.change,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.value,
                style: const TextStyle(
                  color: _textPri,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                m.label,
                style: const TextStyle(color: _textSec, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OVERVIEW ROW (4 pills)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _overviewRow(Map<String, dynamic>? d) {
    final items = [
      ('Total Rides', '${d?['totalRides'] ?? 0}'),
      ('Active Now', '${d?['activeRides'] ?? 0}'),
      ('All Drivers', '${d?['totalDrivers'] ?? 0}'),
      ('Today Rides', '${d?['todayRides'] ?? 0}'),
    ];

    return Row(
      children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 10),
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  e.value.$2,
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  e.value.$1,
                  style: const TextStyle(color: _textSec, fontSize: 9.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _quickActions(BuildContext context) {
    final actions = [
      _ActionData('Drivers', Icons.drive_eta_rounded, '/drivers',
          const Color(0xFFE8F0FE), const Color(0xFF1A73E8)),
      _ActionData('Users', Icons.people_rounded, '/users',
          const Color(0xFFE6F4EA), const Color(0xFF1E8E3E)),
      _ActionData('Orders', Icons.receipt_long_rounded, '/orders',
          const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      _ActionData('Tickets', Icons.support_agent_rounded, '/tickets',
          const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
      _ActionData('Disputes', Icons.gavel_rounded, '/disputes',
          const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ActionData('Alerts', Icons.emergency_rounded, '/alerts',
          const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      _ActionData('Analytics', Icons.analytics_rounded, '/analytics',
          const Color(0xFFE0F7FA), const Color(0xFF00695C)),
      _ActionData('Batch Ops', Icons.batch_prediction_rounded, '/batch',
          const Color(0xFFEDE7F6), const Color(0xFF4527A0)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, a.route),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: a.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(a.icon, color: a.iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  a.label,
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────
class _MetricData {
  final String label, value, change;
  final IconData icon;
  final Color color;
  const _MetricData(this.label, this.value, this.icon, this.color, this.change);
}

class _ActionData {
  final String label, route;
  final IconData icon;
  final Color bg, iconColor;
  const _ActionData(this.label, this.icon, this.route, this.bg, this.iconColor);
}