import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

// ─── Theme tokens — identical across all tabs ─────────────────────────────────
class _T {
  static const bg            = Color(0xFFF5F5F7);
  static const white         = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF1A1A2E);
  static const accent        = Color(0xFFFF6B35);
  static const green         = Color(0xFF00C853);
  static const red           = Color(0xFFFF3B30);
  static const amber         = Color(0xFFFFB300);
  static const purple        = Color(0xFF6C63FF);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x10000000);
  static const divider       = Color(0xFFEEEEEE);
}

class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen>
    with SingleTickerProviderStateMixin {

  DriverProfile? _profile;
  bool           _loading = true;
  Timer?         _refreshTimer;

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      print('🔄 Auto-refreshing driver profile...');
      _load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await ApiService.getDriverProfile();
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return ColoredBox(
      color: _T.bg,
      child: SafeArea(
        child: _loading
            ? _loadingState()
            : FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: _T.accent,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _pageHeader()),
                        SliverToBoxAdapter(child: _profileHeroCard(auth)),
                        SliverToBoxAdapter(child: _statsRow()),
                        SliverToBoxAdapter(child: _vehicleCard()),
                        SliverToBoxAdapter(child: _menuSection(auth)),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _loadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: _T.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: const Center(
          child: SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _T.accent)),
        ),
      ),
      const SizedBox(height: 14),
      const Text('Loading profile…',
          style: TextStyle(color: _T.textSecondary, fontSize: 13)),
    ]),
  );

  // ── Page header ──────────────────────────────────────────────────────────
  Widget _pageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PROFILE',
                style: TextStyle(
                    color: _T.textSecondary, fontSize: 10,
                    letterSpacing: 2, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Your Account',
                style: TextStyle(
                    color: _T.textPrimary, fontSize: 22,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ]),
        ),
        // KYC badge
        if (_profile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _profile!.kycStatus == 'VERIFIED'
                  ? _T.green.withValues(alpha: 0.1)
                  : _T.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _profile!.kycStatus == 'VERIFIED'
                    ? _T.green.withValues(alpha: 0.25)
                    : _T.amber.withValues(alpha: 0.25),
              ),
            ),
            child: Row(children: [
              Icon(
                _profile!.kycStatus == 'VERIFIED'
                    ? Icons.verified_rounded
                    : Icons.pending_rounded,
                color: _profile!.kycStatus == 'VERIFIED' ? _T.green : _T.amber,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                _profile!.kycStatus == 'VERIFIED' ? 'Verified' : 'Pending',
                style: TextStyle(
                    color: _profile!.kycStatus == 'VERIFIED' ? _T.green : _T.amber,
                    fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── Profile hero card ────────────────────────────────────────────────────
  Widget _profileHeroCard(AuthProvider auth) {
    final name    = auth.fullName ?? _profile?.fullName ?? 'Driver';
    final initial = name.substring(0, 1).toUpperCase();
    final phone   = auth.phone ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _T.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: _T.primary.withValues(alpha: 0.28),
                blurRadius: 28, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(children: [
          // Avatar
          _avatar(auth, initial),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.phone_rounded,
                    color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text(phone,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
              ]),
              if (_profile?.rating != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  ...List.generate(5, (i) {
                    final stars = (_profile!.rating is num)
                        ? (_profile!.rating as num).toDouble()
                        : 0.0;
                    if (i < stars.floor()) {
                      return const Icon(Icons.star_rounded, color: _T.amber, size: 13);
                    } else if (i < stars.ceil() && stars % 1 > 0) {
                      return const Icon(Icons.star_half_rounded, color: _T.amber, size: 13);
                    }
                    return Icon(Icons.star_rounded,
                        color: Colors.white.withValues(alpha: 0.15), size: 13);
                  }),
                  const SizedBox(width: 6),
                  Text('${(_profile!.rating is num ? (_profile!.rating as num).toStringAsFixed(1) : _profile!.rating)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  if (_profile!.totalRides != null) ...[
                    const SizedBox(width: 4),
                    Text('(${_profile!.totalRides} rides)',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                  ],
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _avatar(AuthProvider auth, String initial) {
    if (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          ApiService.getImageUrl(_profile!.avatarUrl),
          width: 64, height: 64, fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _initials(initial);
          },
          errorBuilder: (_, __, ___) {
            print('❌ Failed to load driver profile image: ${_profile!.avatarUrl}');
            return _initials(initial);
          },
        ),
      );
    }
    return _initials(initial);
  }

  Widget _initials(String initial) => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(
      color: _T.accent.withValues(alpha: 0.2),
      shape: BoxShape.circle,
      border: Border.all(color: _T.accent.withValues(alpha: 0.4), width: 2),
    ),
    child: Center(
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
    ),
  );

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _statsRow() {
    final rating     = _profile?.rating ?? 0;
    final totalRides = _profile?.totalRides ?? 0;
    final kycOk      = _profile?.kycStatus == 'VERIFIED';

    final items = [
      (_T.amber,  Icons.star_rounded,              '${(rating is num ? (rating as num).toStringAsFixed(1) : rating)}',  'Rating'),
      (_T.green,  Icons.local_shipping_rounded,      '$totalRides',   'Total Rides'),
      (kycOk ? _T.green : _T.amber,
                  kycOk ? Icons.verified_rounded : Icons.pending_rounded,
                  kycOk ? 'Done' : 'Pending',       'KYC Status'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final (color, icon, value, label) = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: _T.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(value,
                      style: const TextStyle(
                          color: _T.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(color: _T.textSecondary, fontSize: 10)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Vehicle card ──────────────────────────────────────────────────────────
  Widget _vehicleCard() {
    if (_profile?.vehicleType == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _T.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: _T.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('VEHICLE',
                  style: TextStyle(
                      color: _T.textSecondary, fontSize: 9,
                      letterSpacing: 1.4, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${_profile!.vehicleType}',
                  style: const TextStyle(
                      color: _T.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              if (_profile!.vehicleNumber != null) ...[
                const SizedBox(height: 2),
                Text(_profile!.vehicleNumber!,
                    style: const TextStyle(color: _T.textSecondary, fontSize: 12)),
              ],
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _T.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _T.green.withValues(alpha: 0.2)),
            ),
            child: const Text('Active',
                style: TextStyle(
                    color: _T.green, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  // ── Menu section ──────────────────────────────────────────────────────────
  Widget _menuSection(AuthProvider auth) {
    final items = [
      (Icons.badge_rounded,         'KYC & Documents', _T.accent,
          () => Navigator.pushNamed(context, '/kyc')),
      (Icons.notifications_rounded, 'Notifications',   _T.purple,
          () => Navigator.pushNamed(context, '/notification-settings')),
      (Icons.help_rounded,          'Help & Support',  const Color(0xFF00BCD4),
          () => Navigator.pushNamed(context, '/support')),
      (Icons.info_rounded,          'About',           _T.textSecondary,
          () {}),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ACCOUNT',
            style: TextStyle(
                color: _T.textSecondary, fontSize: 10,
                letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        // Menu card
        Container(
          decoration: BoxDecoration(
            color: _T.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final (icon, label, color, onTap) = e.value;
              return Column(children: [
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.vertical(
                    top:    i == 0 ? const Radius.circular(18) : Radius.zero,
                    bottom: i == items.length - 1 ? const Radius.circular(18) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                color: _T.textPrimary, fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: _T.textHint, size: 18),
                    ]),
                  ),
                ),
                if (i < items.length - 1)
                  const Divider(
                      color: _T.divider, height: 1,
                      indent: 66, endIndent: 0),
              ]);
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // Logout button
        GestureDetector(
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: _T.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Log Out',
                    style: TextStyle(
                        color: _T.textPrimary, fontWeight: FontWeight.w700)),
                content: const Text('Are you sure you want to log out?',
                    style: TextStyle(color: _T.textSecondary)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: _T.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Log Out',
                        style: TextStyle(color: _T.red, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await auth.logout();
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _T.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3))],
              border: Border.all(color: _T.red.withValues(alpha: 0.15)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: _T.red, size: 18),
                SizedBox(width: 8),
                Text('Log Out',
                    style: TextStyle(
                        color: _T.red, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}