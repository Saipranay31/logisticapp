import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_dashboard_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  // ── Palette (mirrors DriverDashboardScreen) ──────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _orange  = Color(0xFFFF8C42);
  static const Color _red     = Color(0xFFFF3B30);

  List<Map<String, dynamic>> _users    = [];
  List<Map<String, dynamic>> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final r = await ApiService.getAllUsers();
      setState(() {
        _users = r;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              final name  = (u['fullName'] ?? '').toString().toLowerCase();
              final phone = (u['phone'] ?? '').toString().toLowerCase();
              return name.contains(q) || phone.contains(q);
            }).toList();
    });
  }

  void _showUserDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDashboardScreen(user: user, onRefresh: _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
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
      title: const Text(
        'Users',
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
  // SEARCH BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => _applyFilter(),
          style: const TextStyle(color: _textPri, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: _textSec, size: 18),
            hintText: 'Search by name or phone…',
            hintStyle: const TextStyle(color: _textSec, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BODY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
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

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search_rounded, color: _accent, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('No users found',
                style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Try a different name or phone number',
                style: TextStyle(color: _textSec, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _userTile(_filtered[i]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER TILE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _userTile(Map<String, dynamic> u) {
    final name     = u['fullName'] ?? 'Unknown';
    final phone    = u['phone'] ?? '';
    final isActive = u['isActive'] == true;
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: () => _showUserDetail(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: _accent.withOpacity(0.20), width: 1.5),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(color: _accent, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: _textPri,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(phone, style: const TextStyle(color: _textSec, fontSize: 12)),
                ],
              ),
            ),

            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? _green.withOpacity(0.10) : _orange.withOpacity(0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                isActive ? 'Active' : 'Suspended',
                style: TextStyle(
                  color: isActive ? _green : _orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _textSec, size: 18),
          ],
        ),
      ),
    );
  }
}