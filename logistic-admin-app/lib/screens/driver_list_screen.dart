import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'driver_dashboard_screen.dart';

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});
  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
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
  static const Color _red     = Color(0xFFFF3B30);
  static const Color _orange  = Color(0xFFFF8C42);

  String _statusFilter = 'All';
  String _kycFilter    = 'All';
  final _searchCtrl    = TextEditingController();
  List<Map<String, dynamic>> _drivers         = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  bool   _loading = true;
  String _error   = '';

  @override
  void initState() { super.initState(); _loadDrivers(); }

  Future<void> _loadDrivers() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final drivers = await ApiService.getAllDrivers();
      setState(() { _drivers = drivers; _applyFilters(); _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load drivers: $e'; _loading = false; });
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    final filtered = _drivers.where((d) {
      final online = (d['isOnline'] == true || d['online'] == true);
      if (_statusFilter == 'Online'  && !online)  return false;
      if (_statusFilter == 'Offline' &&  online)  return false;

      final kyc = d['kycStatus'] ?? 'PENDING';
      const kycMap = {'Verified': 'VERIFIED', 'Pending': 'PENDING', 'Rejected': 'REJECTED'};
      if (_kycFilter != 'All' && kyc != kycMap[_kycFilter]) return false;

      if (q.isNotEmpty) {
        final name  = (d['fullName'] ?? '').toString().toLowerCase();
        final phone = (d['phone']    ?? '').toString().toLowerCase();
        if (!name.contains(q) && !phone.contains(q)) return false;
      }
      return true;
    }).toList();
    setState(() => _filteredDrivers = filtered);
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
              : Column(children: [
                  _buildSearchBar(),
                  _buildFilterRow(),
                  const SizedBox(height: 4),
                  _buildCountLabel(),
                  Expanded(child: _buildList()),
                ]),
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
      title: const Text('Drivers',
          style: TextStyle(color: _textPri, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: _textSec), onPressed: _loadDrivers),
        const SizedBox(width: 4),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ERROR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _red.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, color: _red, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Something went wrong',
              style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_error, style: const TextStyle(color: _textSec, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _loadDrivers,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => _applyFilters(),
          style: const TextStyle(color: _textPri, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: _textSec, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: _textSec, size: 18),
                    onPressed: () { _searchCtrl.clear(); _applyFilters(); },
                  )
                : null,
            hintText: 'Search by name or phone…',
            hintStyle: const TextStyle(color: _textSec, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILTER ROW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip(
            label: 'Status',
            value: _statusFilter,
            options: ['All', 'Online', 'Offline'],
            onChange: (v) { setState(() => _statusFilter = v); _applyFilters(); },
          ),
          const SizedBox(width: 10),
          _filterChip(
            label: 'KYC',
            value: _kycFilter,
            options: ['All', 'Verified', 'Pending', 'Rejected'],
            onChange: (v) { setState(() => _kycFilter = v); _applyFilters(); },
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChange,
  }) {
    final isActive = value != 'All';
    return PopupMenuButton<String>(
      onSelected: onChange,
      color: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _border)),
      itemBuilder: (_) => options.map((o) => PopupMenuItem(
        value: o,
        child: Text(o, style: TextStyle(
          color: o == value ? _accent : _textPri,
          fontWeight: o == value ? FontWeight.w600 : FontWeight.w400,
          fontSize: 14,
        )),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? _accent.withOpacity(0.08) : _surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: isActive ? _accent.withOpacity(0.30) : _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            value == 'All' ? label : value,
            style: TextStyle(
              color: isActive ? _accent : _textSec,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: isActive ? _accent : _textSec, size: 16),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COUNT LABEL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCountLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Text(
        '${_filteredDrivers.length} driver${_filteredDrivers.length == 1 ? '' : 's'}',
        style: const TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIST
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildList() {
    if (_filteredDrivers.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.drive_eta_rounded, color: _textSec, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('No drivers found',
              style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Try adjusting your filters',
              style: TextStyle(color: _textSec, fontSize: 13)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDrivers,
      color: _accent,
      backgroundColor: _surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filteredDrivers.length,
        itemBuilder: (_, i) => _driverCard(_filteredDrivers[i]),
      ),
    );
  }

  Widget _driverCard(Map<String, dynamic> d) {
    final online  = d['isOnline'] == true || d['online'] == true;
    final kyc     = d['kycStatus'] ?? 'PENDING';
    final rating  = (d['rating'] as num?)?.toDouble() ?? 0.0;
    final initial = ((d['fullName'] ?? 'D') as String)[0].toUpperCase();

    return GestureDetector(
      onTap: () => _showDriverSheet(context, d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withOpacity(0.20), width: 1.5),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(color: _accent, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          // Name + phone
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['fullName'] ?? 'Unknown',
                  style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(d['phone'] ?? '',
                  style: const TextStyle(color: _textSec, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, color: _amber, size: 12),
                const SizedBox(width: 3),
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(color: _textSec, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                _kycBadge(kyc),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          // Status + chevron
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _statusBadge(online),
            const SizedBox(height: 16),
            const Icon(Icons.chevron_right_rounded, color: _textSec, size: 18),
          ]),
        ]),
      ),
    );
  }

  Widget _statusBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (online ? _green : _textSec).withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(
            color: online ? _green : _textSec,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          online ? 'Online' : 'Offline',
          style: TextStyle(color: online ? _green : _textSec, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  Widget _kycBadge(String kyc) {
    final labels = {'VERIFIED': 'Verified', 'PENDING': 'Pending', 'SUBMITTED': 'Review', 'REJECTED': 'Rejected'};
    final colors = {'VERIFIED': _green, 'PENDING': _amber, 'SUBMITTED': _accent, 'REJECTED': _red};
    final label = labels[kyc] ?? kyc;
    final color = colors[kyc] ?? _textSec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text('KYC: $label', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  void _showDriverSheet(BuildContext ctx, Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.70,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (_, scroll) => _DriverProfileSheet(
          driver: driver,
          scrollCtrl: scroll,
          onRefresh: _loadDrivers,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DRIVER PROFILE BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _DriverProfileSheet extends StatefulWidget {
  final Map<String, dynamic> driver;
  final ScrollController scrollCtrl;
  final VoidCallback onRefresh;

  const _DriverProfileSheet({
    required this.driver,
    required this.scrollCtrl,
    required this.onRefresh,
  });

  @override
  State<_DriverProfileSheet> createState() => _DriverProfileSheetState();
}

class _DriverProfileSheetState extends State<_DriverProfileSheet> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _amber   = Color(0xFFFFC72C);
  static const Color _red     = Color(0xFFFF3B30);
  static const Color _orange  = Color(0xFFFF8C42);

  bool _actionLoading = false;

  @override
  Widget build(BuildContext context) {
    final d   = widget.driver;
    final kyc = d['kycStatus'] ?? 'PENDING';
    final kycColor = _kycColor(kyc);
    final rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
    final initial = ((d['fullName'] ?? 'D') as String)[0].toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        controller: widget.scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Profile header ─────────────────────────────────────────────
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: _accent.withOpacity(0.20), width: 2),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(color: _accent, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['fullName'] ?? 'Unknown',
                  style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 3),
              Text(d['phone'] ?? '', style: const TextStyle(color: _textSec, fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 20),

          // ── Stats row ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              _statCell('Rating', '${rating.toStringAsFixed(1)} ★', _amber),
              _vertDiv(),
              _statCell('Total Rides', '${d['totalRides'] ?? 0}', _accent),
              _vertDiv(),
              _statCell('License', d['licenseNumber'] ?? 'N/A', _textSec),
            ]),
          ),
          const SizedBox(height: 16),

          // ── KYC status banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kycColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kycColor.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(_kycIcon(kyc), color: kycColor, size: 20),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('KYC Status', style: TextStyle(color: _textSec, fontSize: 11)),
                const SizedBox(height: 1),
                Text(_kycLabel(kyc),
                    style: TextStyle(color: kycColor, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kycColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(kyc, style: TextStyle(color: kycColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Section label ──────────────────────────────────────────────
          const Text('Actions',
              style: TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // ── Action buttons ─────────────────────────────────────────────
          _actionLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
                  ),
                )
              : Column(children: [

                  // View Dashboard
                  _btn(
                    label: 'View Full Dashboard',
                    icon: Icons.dashboard_rounded,
                    color: _accent,
                    filled: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverDashboardScreen(
                          driver: widget.driver,
                          onRefresh: widget.onRefresh,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // View KYC Documents
                  _btn(
                    label: 'View KYC Documents',
                    icon: Icons.badge_rounded,
                    color: _primary,
                    onTap: _viewDocuments,
                  ),
                  const SizedBox(height: 12),

                  // KYC approve / reject
                  if (kyc != 'VERIFIED') ...[
                    Row(children: [
                      Expanded(child: _btn(label: 'Approve KYC', icon: Icons.check_circle_outline_rounded, color: _green, onTap: () => _approveKyc(true))),
                      const SizedBox(width: 8),
                      Expanded(child: _btn(label: 'Reject KYC', icon: Icons.cancel_outlined, color: _red, onTap: () => _approveKyc(false))),
                    ]),
                    const SizedBox(height: 8),
                  ],

                  // Suspend / Activate
                  Row(children: [
                    Expanded(child: _btn(label: 'Suspend', icon: Icons.pause_circle_outline_rounded, color: _orange, onTap: _suspendDriver)),
                    const SizedBox(width: 8),
                    Expanded(child: _btn(label: 'Activate', icon: Icons.play_circle_outline_rounded, color: _green, onTap: _activateDriver)),
                  ]),
                ]),
        ]),
      ),
    );
  }

  // ── Action button ─────────────────────────────────────────────────────────
  Widget _btn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _actionLoading ? null : onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? color : color.withOpacity(0.08),
          foregroundColor: filled ? Colors.white : color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: filled ? Colors.transparent : color.withOpacity(0.25)),
          ),
        ),
      ),
    );
  }

  Widget _statCell(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSec, fontSize: 10)),
      ]),
    );
  }

  Widget _vertDiv() => Container(width: 1, height: 32, color: _border);

  // ── KYC helpers ───────────────────────────────────────────────────────────
  String  _kycLabel(String s) => const {'VERIFIED': 'Verified', 'REJECTED': 'Rejected', 'SUBMITTED': 'Under Review'}[s] ?? 'Pending Review';
  Color   _kycColor(String s) => const {'VERIFIED': _green,  'REJECTED': _red,  'SUBMITTED': _accent}[s] ?? _amber;
  IconData _kycIcon(String s) => const {'VERIFIED': Icons.verified_rounded, 'REJECTED': Icons.cancel_rounded}[s] ?? Icons.pending_rounded;

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════════
  String? _driverId() {
    final id = widget.driver['userId']?.toString() ?? widget.driver['id']?.toString();
    return (id == null || id.isEmpty || id == 'null') ? null : id;
  }

  Future<void> _viewDocuments() async {
    setState(() => _actionLoading = true);
    try {
      final id = _driverId();
      if (id == null) throw Exception('Driver ID not found. Keys: ${widget.driver.keys.toList()}');
      final docs = await ApiService.getDriverDocuments(id);
      if (!mounted) return;
      setState(() => _actionLoading = false);
      _showDocsDialog(docs);
    } catch (e) {
      setState(() => _actionLoading = false);
      _snack('Error loading documents: $e', isError: true);
    }
  }

  void _showDocsDialog(List<dynamic> docs) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: _accent.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.badge_rounded, color: _accent, size: 17),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('KYC Documents',
                  style: TextStyle(color: _textPri, fontWeight: FontWeight.w700, fontSize: 15))),
              IconButton(icon: const Icon(Icons.close_rounded, color: _textSec, size: 20),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1, color: _border),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: docs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('No documents uploaded',
                          style: const TextStyle(color: _textSec, fontSize: 14))),
                    )
                  : Column(children: docs.map<Widget>((doc) {
                      final docType = doc['documentType'] ?? 'Unknown';
                      final docUrl  = doc['documentUrl']?.toString() ?? '';
                      final fullUrl = ApiService.getImageUrl(docUrl);
                      final status  = doc['status'] ?? 'PENDING';
                      final sc      = _docStatusColor(status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(children: [
                              Expanded(child: Text(
                                docType.toString().replaceAll('_', ' '),
                                style: const TextStyle(color: _textPri, fontWeight: FontWeight.w600, fontSize: 13),
                              )),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: sc.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
                                child: Text(status.toString(), style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ]),
                          ),
                          if (fullUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                              child: Image.network(
                                fullUrl,
                                width: double.infinity, height: 180, fit: BoxFit.cover,
                                headers: {'Authorization': 'Bearer ${ApiService.getToken()}'},
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return SizedBox(height: 180, child: Center(
                                    child: CircularProgressIndicator(
                                      color: _accent,
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ));
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 100, color: _border,
                                  child: const Center(child: Icon(Icons.broken_image_rounded, color: _textSec, size: 28)),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Text('No document URL', style: const TextStyle(color: _textSec, fontSize: 12)),
                            ),
                        ]),
                      );
                    }).toList()),
            ),
          ),
        ]),
      ),
    );
  }

  Color _docStatusColor(String s) => const {
    'APPROVED': _green, 'REJECTED': _red, 'PENDING': _amber,
  }[s] ?? _textSec;

  Future<void> _approveKyc(bool approve) async {
    final confirmed = await _confirmDialog(
      title: approve ? 'Approve KYC?' : 'Reject KYC?',
      body: 'Are you sure you want to ${approve ? 'approve' : 'reject'} KYC for ${widget.driver['fullName']}?',
      confirmLabel: approve ? 'Approve' : 'Reject',
      confirmColor: approve ? _green : _red,
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final id = _driverId();
      if (id == null) throw Exception('Driver ID not found');
      await ApiService.approveKyc(id, approve);
      if (!mounted) return;
      _snack('KYC ${approve ? 'approved' : 'rejected'} successfully', isError: !approve && false);
      widget.onRefresh();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _actionLoading = false);
      _snack('Error: $e', isError: true);
    }
  }

  Future<void> _suspendDriver() async {
    setState(() => _actionLoading = true);
    try {
      final id = _driverId();
      if (id == null) throw Exception('Driver ID not found');
      await ApiService.suspendDriver(id);
      if (!mounted) return;
      _snack('Driver suspended');
      widget.onRefresh();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _actionLoading = false);
      _snack('Error: $e', isError: true);
    }
  }

  Future<void> _activateDriver() async {
    setState(() => _actionLoading = true);
    try {
      final id = _driverId();
      if (id == null) throw Exception('Driver ID not found');
      await ApiService.activateDriver(id);
      if (!mounted) return;
      _snack('Driver activated', isSuccess: true);
      widget.onRefresh();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _actionLoading = false);
      _snack('Error: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  void _snack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _red : isSuccess ? _green : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: _textPri, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(body, style: const TextStyle(color: _textSec, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}