import 'package:flutter/material.dart';
import '../widgets/graphs/bar_chart_widget.dart';
import '../widgets/graphs/donut_chart_widget.dart';

class AnalyticsGraphScreen extends StatelessWidget {
  final Map<String, dynamic>? revenue;
  final Map<String, dynamic>? drivers;
  final Map<String, dynamic>? users;
  final Map<String, dynamic>? payments;
  final Map<String, dynamic>? support;

  const AnalyticsGraphScreen({
    super.key,
    this.revenue,
    this.drivers,
    this.users,
    this.payments,
    this.support,
  });

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _teal    = Color(0xFF00B4D8);
  static const Color _orange  = Color(0xFFFF8C42);
  static const Color _violet  = Color(0xFF7B61FF);
  static const Color _red     = Color(0xFFFF3B30);
  static const Color _amber   = Color(0xFFFFC72C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Revenue ───────────────────────────────────────────────────
            _sectionHeader('Revenue', Icons.currency_rupee_rounded, _green),
            const SizedBox(height: 14),
            _chartCard(
              child: BarChartWidget(
                title: '',
                unit: '₹',
                bars: [
                  BarData(label: 'Total',      value: _d(revenue?['totalRevenue']),       color: _green),
                  BarData(label: 'Commission', value: _d(revenue?['platformCommission']), color: _green.withOpacity(0.70)),
                  BarData(label: 'Driver Pay', value: _d(revenue?['driverPayout']),       color: _green.withOpacity(0.45)),
                  BarData(label: 'Avg Fare',   value: _d(revenue?['averageFare']),        color: _green.withOpacity(0.25)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _chartCard(child: _buildRideCompletionDonut()),
            const SizedBox(height: 28),

            // ── Drivers ───────────────────────────────────────────────────
            _sectionHeader('Drivers', Icons.drive_eta_rounded, _accent),
            const SizedBox(height: 14),
            _chartCard(
              child: BarChartWidget(
                title: '',
                bars: [
                  BarData(label: 'Total',    value: _d(drivers?['totalDrivers']),    color: _accent),
                  BarData(label: 'Online',   value: _d(drivers?['onlineNow']),       color: _green),
                  BarData(label: 'Verified', value: _d(drivers?['verifiedDrivers']), color: _teal),
                  BarData(label: 'Pending',  value: _d(drivers?['pendingKyc']),      color: _amber),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _chartCard(child: _buildDriverStatusDonut()),
            const SizedBox(height: 28),

            // ── Users ─────────────────────────────────────────────────────
            _sectionHeader('Users', Icons.people_rounded, _teal),
            const SizedBox(height: 14),
            _chartCard(
              child: BarChartWidget(
                title: '',
                bars: [
                  BarData(label: 'Total',    value: _d(users?['totalUsers']),   color: _teal),
                  BarData(label: 'New/Week', value: _d(users?['newThisWeek']),  color: _teal.withOpacity(0.50)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Payments ──────────────────────────────────────────────────
            _sectionHeader('Payments', Icons.payment_rounded, _orange),
            const SizedBox(height: 14),
            _chartCard(
              child: BarChartWidget(
                title: '',
                bars: [
                  BarData(label: 'Total',   value: _d(payments?['totalPayments']),      color: _orange),
                  BarData(label: 'Success', value: _d(payments?['successfulPayments']), color: _green),
                  BarData(label: 'Failed',  value: _d(payments?['failedPayments']),     color: _red),
                  BarData(label: 'Pending', value: _d(payments?['pendingPayments']),    color: _amber),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _chartCard(child: _buildPaymentDonut()),
            const SizedBox(height: 28),

            // ── Support ───────────────────────────────────────────────────
            _sectionHeader('Support Tickets', Icons.support_agent_rounded, _violet),
            const SizedBox(height: 14),
            _chartCard(child: _buildSupportDonut()),
            const SizedBox(height: 12),
            _chartCard(
              child: BarChartWidget(
                title: '',
                bars: [
                  BarData(label: 'Total',       value: _d(support?['totalTickets']),       color: _violet),
                  BarData(label: 'Open',        value: _d(support?['openTickets']),        color: _red),
                  BarData(label: 'In Progress', value: _d(support?['inProgressTickets']),  color: _amber),
                  BarData(label: 'Resolved',    value: _d(support?['resolvedTickets']),    color: _green),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
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
        onPressed: () => Navigator.pushReplacementNamed(context, '/main'),
      ),
      title: const Text(
        'Analytics Graphs',
        style: TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
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
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHART CARD WRAPPER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _chartCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DONUT BUILDERS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRideCompletionDonut() {
    final total      = _d(revenue?['totalRides']);
    final rate       = _d(revenue?['completionRate']);
    final completed  = total > 0 ? total * rate / 100 : 0.0;
    final incomplete = total > completed ? total - completed : 0.0;
    return DonutChartWidget(
      title: '',
      centerText: '${rate.toStringAsFixed(0)}%',
      sections: [
        DonutSection(label: 'Completed',  value: completed,  color: _green),
        DonutSection(label: 'Incomplete', value: incomplete, color: _red.withOpacity(0.65)),
      ].where((s) => s.value > 0).toList(),
    );
  }

  Widget _buildDriverStatusDonut() {
    final total   = _d(drivers?['totalDrivers']);
    final online  = _d(drivers?['onlineNow']);
    final offline = total > online ? total - online : 0.0;
    return DonutChartWidget(
      title: '',
      centerText: total > 0
          ? '${online.toInt()}/${total.toInt()}'
          : '',
      sections: [
        DonutSection(label: 'Online',  value: online,  color: _green),
        DonutSection(label: 'Offline', value: offline, color: const Color(0xFFCDD5DF)),
      ].where((s) => s.value > 0).toList(),
    );
  }

  Widget _buildPaymentDonut() {
    return DonutChartWidget(
      title: '',
      centerText: '${_d(payments?["successRate"]).toStringAsFixed(0)}%',
      sections: [
        DonutSection(label: 'Success', value: _d(payments?['successfulPayments']), color: _green),
        DonutSection(label: 'Failed',  value: _d(payments?['failedPayments']),     color: _red),
        DonutSection(label: 'Pending', value: _d(payments?['pendingPayments']),    color: _amber),
      ].where((s) => s.value > 0).toList(),
    );
  }

  Widget _buildSupportDonut() {
    final resolved = _d(support?['resolvedTickets']);
    final rate     = _d(support?['resolutionRate']);
    return DonutChartWidget(
      title: '',
      centerText: '${rate.toStringAsFixed(0)}%',
      sections: [
        DonutSection(label: 'Open',        value: _d(support?['openTickets']),       color: _red),
        DonutSection(label: 'In Progress', value: _d(support?['inProgressTickets']), color: _amber),
        DonutSection(label: 'Resolved',    value: resolved,                          color: _green),
      ].where((s) => s.value > 0).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  double _d(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
}