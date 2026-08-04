import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_stats_graph_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRefresh;

  const UserDashboardScreen({super.key, required this.user, this.onRefresh});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  // ── Palette (mirrors DriverDashboardScreen exactly) ─────────────────────
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

  Map<String, dynamic>? _detail;
  bool _loading = true;
  String _error = '';
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final userId = widget.user['userId']?.toString() ?? widget.user['id']?.toString() ?? '';
      final data = await ApiService.getUserDetail(userId);
      setState(() { _detail = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _suspend() async {
    setState(() => _actionLoading = true);
    try {
      final userId = widget.user['userId']?.toString() ?? widget.user['id']?.toString() ?? '';
      await ApiService.suspendUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User suspended'), backgroundColor: Colors.orange),
      );
      widget.onRefresh?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _activate() async {
    setState(() => _actionLoading = true);
    try {
      final userId = widget.user['userId']?.toString() ?? widget.user['id']?.toString() ?? '';
      await ApiService.activateUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User activated'), backgroundColor: Color(0xFF00C48C)),
      );
      widget.onRefresh?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
          : _error.isNotEmpty
              ? _buildError()
              : _buildContent(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
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
        'User Profile',
        style: TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textSec),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: _red, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_error,
                style: const TextStyle(color: _textSec, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN CONTENT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildContent() {
    final d = _detail!;
    final isActive = d['isActive'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile card ─────────────────────────────────────────────────
          _profileCard(d, isActive),
          const SizedBox(height: 24),

          // ── Ride analytics ────────────────────────────────────────────────
          _sectionLabel('Ride Activity'),
          const SizedBox(height: 14),
          _periodRow(d),
          const SizedBox(height: 12),
          _totalSpentCard(d),
          const SizedBox(height: 24),

          // ── Ratings ───────────────────────────────────────────────────────
          _sectionLabel('User Ratings'),
          const SizedBox(height: 14),
          _buildRatingsCard(d),
          const SizedBox(height: 24),

          // ── View graphs ───────────────────────────────────────────────────
          _graphButton(d),
          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────────────
          _sectionLabel('Actions'),
          const SizedBox(height: 14),
          _actionLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
                  ),
                )
              : _actionRow(isActive),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _profileCard(Map<String, dynamic> d, bool isActive) {
    final name = d['fullName'] ?? 'Unknown';
    final avg  = (d['averageRating'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Avatar + name row
          Row(
            children: [
              _buildAvatar(d['avatarUrl'], name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d['phone'] ?? '',
                      style: const TextStyle(color: _textSec, fontSize: 13),
                    ),
                    if ((d['email'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        d['email'] ?? '',
                        style: const TextStyle(color: _textSec, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statusChip(
                          isActive ? 'Active' : 'Suspended',
                          isActive ? _accent : _orange,
                          isActive ? _accent.withOpacity(0.10) : _orange.withOpacity(0.10),
                        ),
                        if ((d['joinedAt'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _statusChip(
                            'Since ${_formatDate(d['joinedAt']?.toString() ?? '')}',
                            _textSec,
                            _textSec.withOpacity(0.08),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 16),

          // Stats pills row
          Row(
            children: [
              _infoTile('Rating', avg > 0 ? avg.toStringAsFixed(1) : 'N/A', Icons.star_rounded, _amber),
              _vertDivider(),
              _infoTile('Total Rides', '${d['totalRides'] ?? 0}', Icons.route_rounded, _accent),
              _vertDivider(),
              _infoTile('Total Spent', '₹${(d['totalSpent'] ?? 0.0 as num).toStringAsFixed(0)}', Icons.currency_rupee_rounded, _green),
              _vertDivider(),
              _infoTile('Ratings', '${d['totalRatings'] ?? 0}', Icons.thumb_up_rounded, _textSec),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(color: _textPri, fontSize: 12, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(color: _textSec, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(width: 1, height: 48, color: _border);

  // ══════════════════════════════════════════════════════════════════════════
  // PERIOD CARDS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _periodRow(Map<String, dynamic> d) {
    final periods = [
      ('Today', d['todayRides'] ?? 0, d['todaySpent'] ?? 0.0),
      ('This Week', d['weekRides'] ?? 0, d['weekSpent'] ?? 0.0),
      ('This Month', d['monthRides'] ?? 0, d['monthSpent'] ?? 0.0),
    ];

    return Row(
      children: periods.asMap().entries.map((e) {
        final isLast = e.key == periods.length - 1;
        final p = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.$1, style: const TextStyle(color: _textSec, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '${p.$2}',
                  style: const TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const Text('rides', style: TextStyle(color: _textSec, fontSize: 10)),
                const SizedBox(height: 6),
                Text(
                  '₹${(p.$3 as num).toStringAsFixed(0)}',
                  style: const TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Text('spent', style: TextStyle(color: _textSec, fontSize: 10)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOTAL SPENT CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _totalSpentCard(Map<String, dynamic> d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Spent (All Time)',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${(d['totalSpent'] ?? 0.0 as num).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '↑ Lifetime',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RATINGS CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRatingsCard(Map<String, dynamic> d) {
    final avg   = (d['averageRating'] as num?)?.toDouble() ?? 0.0;
    final total = d['totalRatings'] ?? 0;
    final dist  = d['ratingDistribution'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: total == 0
          ? Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_outline_rounded, color: _amber, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('No ratings yet', style: TextStyle(color: _textSec, fontSize: 14)),
              ],
            )
          : Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big number
                    Column(
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _textPri,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                          ),
                        ),
                        _starRow(avg),
                        const SizedBox(height: 4),
                        Text(
                          '$total rating${total == 1 ? '' : 's'}',
                          style: const TextStyle(color: _textSec, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'by drivers',
                          style: TextStyle(color: _textSec, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // Distribution bars
                    Expanded(
                      child: Column(
                        children: List.generate(5, (i) {
                          final star = 5 - i;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _ratingBar(
                              star,
                              (dist['${star}stars'] as num?)?.toInt() ?? 0,
                              (total as num).toInt(),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _starRow(double avg) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < avg.floor();
        final half   = !filled && i < avg;
        return Icon(
          half ? Icons.star_half_rounded : (filled ? Icons.star_rounded : Icons.star_outline_rounded),
          color: _amber,
          size: 14,
        );
      }),
    );
  }

  Widget _ratingBar(int star, int count, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        Text('$star', style: const TextStyle(color: _textSec, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        const Icon(Icons.star_rounded, color: _amber, size: 10),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: _border,
              valueColor: const AlwaysStoppedAnimation<Color>(_amber),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 22,
          child: Text('$count',
              style: const TextStyle(color: _textSec, fontSize: 11), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GRAPH BUTTON
  // ══════════════════════════════════════════════════════════════════════════
  Widget _graphButton(Map<String, dynamic> d) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserStatsGraphScreen(detail: d)),
        ),
        icon: const Icon(Icons.bar_chart_rounded, size: 18),
        label: const Text('View Analytics Graphs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _accent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTION ROW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _actionRow(bool isActive) {
    return Row(
      children: [
        // Suspend
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isActive ? _suspend : null,
              icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
              label: const Text('Suspend', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? _orange.withOpacity(0.10) : _border,
                foregroundColor: isActive ? _orange : _textSec,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isActive ? _orange.withOpacity(0.30) : _border),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Activate
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: !isActive ? _activate : null,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text('Activate', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: !isActive ? _green.withOpacity(0.10) : _border,
                foregroundColor: !isActive ? _green : _textSec,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: !isActive ? _green.withOpacity(0.30) : _border),
                ),
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildAvatar(String? avatarUrl, String name) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final url = ApiService.getImageUrl(avatarUrl);
      return CircleAvatar(
        radius: 34,
        backgroundColor: _border,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.10),
        shape: BoxShape.circle,
        border: Border.all(color: _accent.withOpacity(0.20), width: 2),
      ),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(color: _accent, fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}