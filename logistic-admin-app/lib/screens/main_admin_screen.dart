import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/admin_nav_bar.dart';
import 'dashboard_screen.dart';
import 'driver_list_screen.dart';
import 'users_list_screen.dart';
import 'active_orders_screen.dart';
import 'analytics_screen.dart';
import 'support_tickets_screen.dart';
import 'disputes_screen.dart';
import 'emergency_alerts_screen.dart';
import 'payout_management_screen.dart';
import 'batch_operations_screen.dart';

class MainAdminScreen extends StatefulWidget {
  const MainAdminScreen({super.key});

  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen>
    with TickerProviderStateMixin {
  // ── Palette (matches DriverDashboardScreen / ActiveOrdersScreen) ──────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _amber   = Color(0xFFFFC72C);
  static const Color _red     = Color(0xFFFF3B30);
  static const Color _orange  = Color(0xFFFF8C42);

  int _currentIndex = 0;
  late final AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<Widget> _tabs = const [
    DashboardScreen(),
    DriverListScreen(),
    UsersListScreen(),
    ActiveOrdersScreen(),
    AnalyticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.015),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    _fadeCtrl.reset();
    setState(() => _currentIndex = index);
    _fadeCtrl.forward();
  }

  void _pushSecondary(Widget screen) {
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _surface,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        drawer: _buildDrawer(),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAV BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    const items = [
      (Icons.dashboard_rounded,         Icons.dashboard_outlined,         'Dashboard'),
      (Icons.directions_car_rounded,    Icons.directions_car_outlined,    'Drivers'),
      (Icons.people_rounded,            Icons.people_outline_rounded,     'Users'),
      (Icons.receipt_long_rounded,      Icons.receipt_long_outlined,      'Orders'),
      (Icons.bar_chart_rounded,         Icons.bar_chart_outlined,         'Analytics'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: items.asMap().entries.map((e) {
              final i        = e.key;
              final selected = _currentIndex == i;
              final item     = e.value;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabTapped(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Indicator dot
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: selected ? 20 : 0,
                          height: 2.5,
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Icon(
                          selected ? item.$1 : item.$2,
                          color: selected ? _accent : _textSec,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: selected ? _accent : _textSec,
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DRAWER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _buildDrawerHeader(),

            // ── Divider ─────────────────────────────────────────────────
            const Divider(height: 1, color: _border),
            const SizedBox(height: 8),

            // ── Section label ────────────────────────────────────────────
            _drawerSectionLabel('QUICK ACCESS'),

            // ── Items ────────────────────────────────────────────────────
            _drawerItem(
              Icons.support_agent_rounded,
              'Support Tickets',
              'Manage customer support',
              _accent,
              () => _pushSecondary(const SupportTicketsScreen()),
            ),
            _drawerItem(
              Icons.gavel_rounded,
              'Disputes',
              'Resolve ride disputes',
              _orange,
              () => _pushSecondary(const DisputesScreen()),
            ),
            _drawerItem(
              Icons.emergency_rounded,
              'Emergency Alerts',
              'Active SOS & alerts',
              _red,
              () => _pushSecondary(const EmergencyAlertsScreen()),
            ),
            _drawerItem(
              Icons.account_balance_wallet_rounded,
              'Payouts & Payments',
              'Driver payouts & transactions',
              _green,
              () => _pushSecondary(const PayoutManagementScreen()),
            ),
            _drawerItem(
              Icons.settings_applications_rounded,
              'Batch Operations',
              'Bulk driver & order actions',
              _primary,
              () => _pushSecondary(const BatchOperationsScreen()),
            ),

            const Spacer(),

            // ── Footer ───────────────────────────────────────────────────
            const Divider(height: 1, color: _border),
            const SizedBox(height: 4),
            _drawerItem(
              Icons.logout_rounded,
              'Logout',
              'Sign out of admin console',
              _red,
              () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      color: _surface,
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Porter Admin',
                style: TextStyle(
                  color: _textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Management Console',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      splashColor: color.withOpacity(0.06),
      highlightColor: color.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _textPri,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _textSec, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _border, size: 18),
          ],
        ),
      ),
    );
  }
}