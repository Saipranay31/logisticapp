import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../widgets/navigation.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors (same system) ───────────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _primaryText = Color(0xFF1A1A1A);
  static const Color _green = Color(0xFF00C853);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _amber = Color(0xFFFFB300);

  // ── State (UNCHANGED logic) ────────────────────────────────
  String _filter = 'ALL';
 

  static const _filters = [
    {'value': 'ALL', 'label': 'All'},
    {'value': 'COMPLETED', 'label': 'Completed'},
    {'value': 'CANCELLED', 'label': 'Cancelled'},
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();

    Future.microtask(
      () => Provider.of<RideProvider>(context, listen: false).fetchRideHistory(),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Helpers (UNCHANGED) ────────────────────────────────────
  String _vehicleEmoji(String? type) {
    switch (type) {
      case 'BIKE': return '🏍️';
      case 'AUTO': return '🛺';
      case 'TRUCK': return '🚚';
      case 'MINI_TRUCK': return '🚛';
      default: return '📦';
    }
  }

  String _vehicleLabel(String? type) {
    switch (type) {
      case 'BIKE': return 'Bike';
      case 'AUTO': return 'Auto';
      case 'TRUCK': return 'Truck';
      case 'MINI_TRUCK': return 'Mini Truck';
      default: return 'Vehicle';
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (s.length < 10) return s;
    try {
      final dt = DateTime.parse(s);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return s.substring(0, 10);
    }
  }

  
  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _surface,
        body: Consumer<RideProvider>(
          builder: (_, ride, __) {
            final all = ride.rideHistory;
            final filtered = _filter == 'ALL'
                ? all
                : all.where((r) => r['status'] == _filter).toList();

            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Header ──────────────────────────────
                    SliverToBoxAdapter(child: _buildHeader(all)),

                    // ── Summary cards ────────────────────────
                    SliverToBoxAdapter(child: _buildSummaryRow(all)),

                    // ── Filter chips ─────────────────────────
                    SliverToBoxAdapter(child: _buildFilterRow()),

                    // ── Section label ─────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text(
                          filtered.isEmpty ? '' : '${filtered.length} ${_filter == 'ALL' ? 'total' : _filter.toLowerCase()} ride${filtered.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: _hint, fontSize: 12, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    // ── Content ───────────────────────────────
                    if (ride.isLoading)
                      const SliverFillRemaining(child: _LoadingState())
                    else if (filtered.isEmpty)
                      const SliverFillRemaining(child: _EmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _buildRideCard(filtered[i], i),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(List all) {
    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20, left: 20, right: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MY DELIVERIES',
                style: TextStyle(
                  color: _hint,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'History',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Rides count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_rounded, size: 13, color: _black),
                const SizedBox(width: 5),
                Text(
                  '${all.length} rides',
                  style: const TextStyle(
                    color: _primaryText, fontSize: 12, fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary cards ──────────────────────────────────────────
  Widget _buildSummaryRow(List all) {
    final completed = all.where((r) => r['status'] == 'COMPLETED').length;
    final cancelled = all.where((r) => r['status'] == 'CANCELLED').length;
    final totalSpend = all.fold<double>(
      0,
      (sum, r) => sum + ((r['actualFare'] ?? r['estimatedFare'] ?? 0) as num).toDouble(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _summaryCard(
            icon: Icons.check_circle_rounded,
            iconColor: _green,
            value: '$completed',
            label: 'Completed',
          ),
          const SizedBox(width: 10),
          _summaryCard(
            icon: Icons.cancel_rounded,
            iconColor: _red,
            value: '$cancelled',
            label: 'Cancelled',
          ),
          const SizedBox(width: 10),
          _summaryCard(
            icon: Icons.currency_rupee_rounded,
            iconColor: _black,
            value: '₹${totalSpend.toStringAsFixed(0)}',
            label: 'Total Spent',
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: _primaryText, fontSize: 17, fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: _hint, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: _filters.map((f) {
          final val = f['value']!;
          final label = f['label']!;
          final active = _filter == val;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _filter = val);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? _black : _white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? _black : _divider, width: active ? 1.5 : 1,
                  ),
                  boxShadow: active
                      ? [BoxShadow(color: _black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? _white : _hint,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Ride card ──────────────────────────────────────────────
  Widget _buildRideCard(Map r, int index) {
    final completed = r['status'] == 'COMPLETED';
    final fare = (r['actualFare'] ?? r['estimatedFare'] ?? 0) as num;
    final statusColor = completed ? _green : _red;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 50),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // ── Top status bar ────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border(bottom: BorderSide(color: _divider, width: 1)),
                ),
                child: Row(
                  children: [
                    Text(_vehicleEmoji(r['vehicleType']),
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      _vehicleLabel(r['vehicleType']),
                      style: const TextStyle(
                        color: _primaryText, fontSize: 12, fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            completed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: statusColor, size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            completed ? 'Completed' : 'Cancelled',
                            style: TextStyle(
                              color: statusColor, fontSize: 10, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Route ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dot-line-dot connector
                    Column(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: _green, shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 1.5, height: 28,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: _divider,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: _red, shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['pickupAddress'] ?? 'Pickup',
                            style: const TextStyle(
                              color: _primaryText, fontSize: 13, fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            r['dropAddress'] ?? 'Drop',
                            style: const TextStyle(
                              color: _primaryText, fontSize: 13, fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer: date + fare ───────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _divider, width: 1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 11, color: _hint),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(r['createdAt']),
                      style: const TextStyle(
                        color: _hint, fontSize: 11, fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${fare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _primaryText, fontSize: 16, fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Color(0xFF9E9E9E), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No deliveries found',
            style: TextStyle(
              color: Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your ride history will appear here',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Loading state ──────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF0A0A0A), strokeWidth: 2.5,
      ),
    );
  }
}