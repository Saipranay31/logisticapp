import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/navigation.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
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
  static const Color _blue = Color(0xFF276EF1);

  // ── State (UNCHANGED logic) ────────────────────────────────
  Map<String, dynamic>? _profile;
  int _addressCount = 0;
  bool _loadingProfile = true;
  

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
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Logic (UNCHANGED) ──────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final profile = await ApiService.getUserProfile();
      if (mounted && profile != null) {
        setState(() => _profile = {
          'fullName': profile.fullName,
          'phone': profile.phone,
          'id': profile.id,
        });
      }
    } catch (_) {}

    try {
      final addrs = await ApiService.getAddresses();
      if (mounted) setState(() => _addressCount = addrs is List ? addrs.length : 0);
    } catch (_) {}

    if (mounted) setState(() => _loadingProfile = false);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 1).toUpperCase();
  }

  

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: _hint, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: _hint, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red.withOpacity(0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final name = _profile?['fullName'] ?? auth.fullName ?? 'User';
    final phone = _profile?['phone'] ?? auth.phone ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _surface,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: RefreshIndicator(
              onRefresh: _loadProfile,
              color: _black,
              backgroundColor: _white,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ── Header ──────────────────────────────
                  SliverToBoxAdapter(child: _buildHeader()),

                  // ── Profile card ─────────────────────────
                  SliverToBoxAdapter(child: _buildProfileCard(name, phone)),

                  // ── Stats strip ──────────────────────────
                  SliverToBoxAdapter(child: _buildStatsRow()),

                  // ── Preferences ──────────────────────────
                  SliverToBoxAdapter(child: _buildSectionLabel('Preferences')),
                  SliverToBoxAdapter(child: _buildMenuSection(_preferencesItems(context))),

                  // ── Support ──────────────────────────────
                  SliverToBoxAdapter(child: _buildSectionLabel('Support')),
                  SliverToBoxAdapter(child: _buildMenuSection(_supportItems(context))),

                  // ── Account ──────────────────────────────
                  SliverToBoxAdapter(child: _buildSectionLabel('Account')),
                  SliverToBoxAdapter(child: _buildMenuSection(_accountItems(context))),

                  // ── Logout ───────────────────────────────
                  SliverToBoxAdapter(child: _buildLogoutButton()),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
        
      ),
    );
  }

  // ── Top header bar ─────────────────────────────────────────
  Widget _buildHeader() {
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
                'MY PROFILE',
                style: TextStyle(
                  color: _hint, fontSize: 10,
                  letterSpacing: 1.8, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Account',
                style: TextStyle(
                  color: _primaryText, fontSize: 28,
                  fontWeight: FontWeight.w900, letterSpacing: -1,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Settings icon button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _divider),
              ),
              child: const Icon(Icons.settings_outlined, color: _black, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile card ───────────────────────────────────────────
  Widget _buildProfileCard(String name, String phone) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _black.withOpacity(0.18),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _loadingProfile
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            )
          : Row(
              children: [
                // Avatar circle
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800, letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_rounded,
                              size: 11, color: Colors.white.withOpacity(0.45)),
                          const SizedBox(width: 4),
                          Text(
                            phone.isNotEmpty ? phone : 'No phone added',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5), fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Stats strip ────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _statCard(
            icon: Icons.location_on_rounded,
            iconColor: _blue,
            value: _addressCount > 0 ? '$_addressCount' : '0',
            label: 'Addresses',
          ),
          
         
          const SizedBox(width: 10),
          
        ],
      ),
    );
  }

  Widget _statCard({
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
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: _primaryText, fontSize: 15,
                fontWeight: FontWeight.w900, letterSpacing: -0.3,
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

  // ── Section label ──────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _hint, fontSize: 10,
          letterSpacing: 1.8, fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Menu section ───────────────────────────────────────────
  Widget _buildMenuSection(List<_MenuItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: List.generate(items.length, (i) {
            return _buildMenuItem(items[i], i == items.length - 1);
          }),
        ),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item, bool isLast) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
        splashColor: _surface,
        highlightColor: _surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: item.iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 18),
                  ),
                  const SizedBox(width: 14),
                  // Label
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: _primaryText, fontSize: 14, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Badge
                  if (item.badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          color: _primaryText, fontSize: 11, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  Icon(Icons.chevron_right_rounded, color: _hint, size: 18),
                ],
              ),
            ),
            if (!isLast)
              Divider(height: 1, indent: 68, color: _divider),
          ],
        ),
      ),
    );
  }

  // ── Menu item groups (UNCHANGED logic) ────────────────────
  List<_MenuItem> _preferencesItems(BuildContext context) => [
    _MenuItem(
      icon: Icons.location_on_rounded,
      label: 'Saved Addresses',
      badge: _addressCount > 0 ? '$_addressCount saved' : null,
      iconColor: _blue,
      onTap: () {},
    ),
    _MenuItem(
      icon: Icons.payment_rounded,
      label: 'Payment Methods',
      iconColor: _green,
      onTap: () {},
    ),
    _MenuItem(
      icon: Icons.notifications_rounded,
      label: 'Notifications',
      iconColor: _amber,
      //onTap: () => Navigator.pushNamed(context, '/notification-settings'),
      onTap: () => Navigator.pushNamed(context, ''),
    ),
  ];

  List<_MenuItem> _supportItems(BuildContext context) => [
    _MenuItem(
      icon: Icons.emergency_rounded,
      label: 'Emergency Contacts',
      iconColor: _red,
     // onTap: () => Navigator.pushNamed(context, '/emergency-contacts'),
      onTap: () => Navigator.pushNamed(context, ''),
    ),
    _MenuItem(
      icon: Icons.support_agent_rounded,
      label: 'Help & Support',
      iconColor: _blue,
      onTap: () => Navigator.pushNamed(context, '/support'),
    ),
    _MenuItem(
      icon: Icons.card_giftcard_rounded,
      label: 'Refer & Earn',
      badge: '₹100',
      iconColor: const Color(0xFFAB47BC),
      onTap: () {},
    ),
  ];

  List<_MenuItem> _accountItems(BuildContext context) => [
    _MenuItem(
      icon: Icons.shield_rounded,
      label: 'Privacy & Security',
      iconColor: _green,
      onTap: () {},
    ),
    _MenuItem(
      icon: Icons.info_rounded,
      label: 'About',
      iconColor: _hint,
      onTap: () {},
    ),
  ];

  // ── Logout button ──────────────────────────────────────────
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _logout();
        },
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: _red.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _red.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.logout_rounded, color: _red, size: 18),
              SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  color: _red, fontSize: 15, fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu item model (UNCHANGED) ────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String label;
  final String? badge;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.badge,
  });
}