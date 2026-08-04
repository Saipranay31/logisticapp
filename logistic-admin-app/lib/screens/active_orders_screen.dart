import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});
  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
  // ── Palette (matches DriverDashboardScreen) ───────────────────────────────
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
  static const Color _purple  = Color(0xFF9C27B0);
  static const Color _teal    = Color(0xFF00897B);

  List<dynamic> _rides = [];
  bool _loading = true;
  String _selectedStatus = 'ACTIVE';
  final _searchCtrl = TextEditingController();
  String _searchText = '';

  static const _filters = [
    ('All', 'ALL'),
    ('Active', 'ACTIVE'),
    ('Requested', 'REQUESTED'),
    ('Searching', 'SEARCHING'),
    ('Assigned', 'ASSIGNED'),
    ('Arrived', 'ARRIVED'),
    ('In Progress', 'IN_PROGRESS'),
    ('Completed', 'COMPLETED'),
    ('Cancelled', 'CANCELLED'),
  ];

  static Color _statusColor(String status) => switch (status) {
        'REQUESTED'   => _amber,
        'SEARCHING'   => _purple,
        'ASSIGNED'    => _accent,
        'ARRIVED'     => _teal,
        'IN_PROGRESS' => _green,
        'COMPLETED'   => const Color(0xFF8A94A6),
        'CANCELLED'   => _red,
        _             => const Color(0xFF8A94A6),
      };

  static IconData _statusIcon(String status) => switch (status) {
        'REQUESTED'   => Icons.access_time_rounded,
        'SEARCHING'   => Icons.search_rounded,
        'ASSIGNED'    => Icons.person_pin_rounded,
        'ARRIVED'     => Icons.where_to_vote_rounded,
        'IN_PROGRESS' => Icons.directions_car_rounded,
        'COMPLETED'   => Icons.check_circle_rounded,
        'CANCELLED'   => Icons.cancel_rounded,
        _             => Icons.circle_outlined,
      };

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(
      () => setState(() => _searchText = _searchCtrl.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getAdminRides(status: _selectedStatus);
      setState(() => _rides = r);
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    if (_searchText.isEmpty) return _rides;
    return _rides.where((o) {
      final pickup = (o['pickupAddress'] ?? '').toString().toLowerCase();
      final drop   = (o['dropAddress']   ?? '').toString().toLowerCase();
      final driver = (o['driverName']    ?? '').toString().toLowerCase();
      final user   = (o['userName']      ?? '').toString().toLowerCase();
      return pickup.contains(_searchText) ||
          drop.contains(_searchText) ||
          driver.contains(_searchText) ||
          user.contains(_searchText);
    }).toList();
  }

  // ── Stats summary counts ────────────────────────────────────────────────
  Map<String, int> get _statusCounts {
    final map = <String, int>{};
    for (final r in _rides) {
      final s = (r['status'] ?? '') as String;
      map[s] = (map[s] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(filtered.length),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          _buildSearchBar(),

          // ── Filter chips ────────────────────────────────────────────────
          _buildFilterChips(),

          // ── Live summary pills (only when ALL or ACTIVE) ────────────────
          if (!_loading && _rides.isNotEmpty && (_selectedStatus == 'ALL' || _selectedStatus == 'ACTIVE'))
            _buildSummaryStrip(),

          // ── Divider ─────────────────────────────────────────────────────
          const Divider(height: 1, color: _border),

          // ── Order list ──────────────────────────────────────────────────
          Expanded(child: _buildList(filtered)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(int count) {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Orders',
            style: TextStyle(
              color: _textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            _loading
                ? 'Loading…'
                : '$count order${count == 1 ? '' : 's'}',
            style: const TextStyle(color: _textSec, fontSize: 11),
          ),
        ],
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
  // SEARCH BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: _textPri, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by address, driver or rider…',
            hintStyle: const TextStyle(color: _textSec, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _textSec, size: 18),
            suffixIcon: _searchText.isNotEmpty
                ? GestureDetector(
                    onTap: () => _searchCtrl.clear(),
                    child: const Icon(Icons.close_rounded, color: _textSec, size: 17),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILTER CHIPS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFilterChips() {
    return Container(
      color: _surface,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (label, value) = _filters[i];
                final selected = _selectedStatus == value;
                return GestureDetector(
                  onTap: () {
                    if (_selectedStatus == value) return;
                    setState(() => _selectedStatus = value);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? _primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? _primary : _border,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : _textSec,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUMMARY STRIP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSummaryStrip() {
    final counts = _statusCounts;
    final liveStatuses = ['IN_PROGRESS', 'ASSIGNED', 'SEARCHING', 'REQUESTED'];
    final liveItems = liveStatuses
        .where((s) => (counts[s] ?? 0) > 0)
        .map((s) => (s, counts[s]!))
        .toList();
    if (liveItems.isEmpty) return const SizedBox.shrink();

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: liveItems.map((e) {
          final color = _statusColor(e.$1);
          final label = e.$1.replaceAll('_', ' ');
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withOpacity(0.20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${e.$2} $label',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIST
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildList(List<dynamic> filtered) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _border,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_outlined, color: _textSec, size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              'No orders found',
              style: TextStyle(
                color: _textPri,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your filter or search',
              style: TextStyle(color: _textSec, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _OrderCard(order: filtered[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ORDER CARD
// ════════════════════════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final dynamic order;
  const _OrderCard({required this.order});

  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _red     = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final status      = (order['status']        ?? '') as String;
    final color       = _ActiveOrdersScreenState._statusColor(status);
    final icon        = _ActiveOrdersScreenState._statusIcon(status);
    final fare        = (order['estimatedFare'] as num?)?.toStringAsFixed(0) ?? '0';
    final pickup      = (order['pickupAddress'] ?? '') as String;
    final drop        = (order['dropAddress']   ?? '') as String;
    final driverName  = (order['driverName']    ?? '') as String;
    final userName    = (order['userName']      ?? '') as String;
    final vehicleType = (order['vehicleType']   ?? '') as String;
    final driverPhone = (order['driverPhone']   ?? '') as String;
    final distance    = order['distanceKm'] as num?;
    final duration    = order['durationMin'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // Status icon badge
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                // Status label + vehicle type
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (vehicleType.isNotEmpty)
                      Text(
                        vehicleType,
                        style: const TextStyle(color: _textSec, fontSize: 11),
                      ),
                  ],
                ),
                const Spacer(),
                // Fare
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹$fare',
                      style: const TextStyle(
                        color: _textPri,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (distance != null)
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: const TextStyle(color: _textSec, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          const Divider(height: 1, color: _border, indent: 14, endIndent: 14),

          // ── Route ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline dots + connector
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: _border,
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: _red, width: 1.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Addresses
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickup.isNotEmpty ? pickup : 'Pickup address',
                          style: const TextStyle(
                            color: _textPri,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          drop.isNotEmpty ? drop : 'Drop address',
                          style: const TextStyle(color: _textSec, fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer: driver + rider ───────────────────────────────────────
          if (driverName.isNotEmpty || userName.isNotEmpty) ...[
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F8FA),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              child: Row(
                children: [
                  if (driverName.isNotEmpty) ...[
                    const Icon(Icons.directions_car_rounded, size: 13, color: _accent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        driverName,
                        style: const TextStyle(
                          color: _textPri,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (driverPhone.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· $driverPhone',
                        style: const TextStyle(color: _textSec, fontSize: 11),
                      ),
                    ],
                  ],
                  if (driverName.isNotEmpty && userName.isNotEmpty) ...[
                    Container(
                      width: 1,
                      height: 12,
                      color: _border,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ],
                  if (userName.isNotEmpty) ...[
                    const Icon(Icons.person_rounded, size: 13, color: Color(0xFF00897B)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: _textPri,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (duration != null) ...[
                    const Spacer(),
                    Text(
                      '${duration.toInt()} min',
                      style: const TextStyle(color: _textSec, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}