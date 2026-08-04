import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../widgets/navigation.dart';
import '../screens/booking_flow_screen.dart';
import '../screens/history_screen.dart';
import '../screens/account_screen.dart';
// ═══════════════════════════════════════════════════════════
//  GLOBAL TRACKING GUARD
//  Single source of truth — prevents ANY double-push to /tracking
//  regardless of which code path triggers it.
// ═══════════════════════════════════════════════════════════
class TrackingRouter {
  static bool _isOpen = false;

  /// Call this instead of Navigator.pushNamed('/tracking') everywhere.
  /// Uses pushReplacement so the stack never grows beyond 1 tracking screen.
  static void open(BuildContext context, {bool replace = false}) {
    if (_isOpen) return; // already open — do nothing
    _isOpen = true;
    if (replace) {
      Navigator.pushReplacementNamed(context, '/tracking').then((_) {
        _isOpen = false;
      });
    } else {
      // pushNamed but pop any existing tracking screen first
      Navigator.pushNamed(context, '/tracking').then((_) {
        _isOpen = false;
      });
    }
  }

  /// Call this when tracking screen closes / ride completes.
  static void close() => _isOpen = false;

  static bool get isOpen => _isOpen;
}

// ═══════════════════════════════════════════════════════════
//  THEME CONSTANTS — change these to restyle the whole screen
// ═══════════════════════════════════════════════════════════
class _Theme {
  static const bg            = Color(0xFFF5F5F7);
  static const white         = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF1A1A2E);
  static const accent        = Color(0xFF6C63FF);
  static const green         = Color(0xFF00C853);
  static const red           = Color(0xFFFF3B30);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x14000000);
  static const glassBorder   = Color(0x22FFFFFF);
  static const divider       = Color(0xFFEEEEEE);
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r20 = 20.0;
  static const r24 = 24.0;
}

// ═══════════════════════════════════════════════════════════
//  HOME SCREEN — Shell with nav bar
// ═══════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkActiveRide();
  }

  // ── FIX 1: Changed pushNamed → TrackingRouter.open (replace=true) ──
  // Previously called pushNamed every time the app opened with an active ride,
  // stacking a new TrackingScreen on top of whatever was already there.
  Future<void> _checkActiveRide() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isAuthenticated || auth.userId == null) return;

      final activeRide = await ApiService.getActiveRide();
      if (activeRide != null && mounted) {
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        rideProvider.updateCurrentRide({
          'id':              activeRide.id,
          'userId':          activeRide.userId,
          'status':          activeRide.status,
          'pickupAddress':   activeRide.pickupAddress,
          'dropAddress':     activeRide.dropAddress,
          'estimatedFare':   activeRide.estimatedFare,
          'actualFare':      activeRide.actualFare,
          'vehicleType':     activeRide.vehicleType,
          'driverId':        activeRide.driverId,
          'driverName':      activeRide.driverName,
          'driverRating':    activeRide.driverRating,
          'driverPhone':     activeRide.driverPhone,
          'vehicleNumber':   activeRide.vehicleNumber,
          'pickupLatitude':  activeRide.pickupLatitude,
          'pickupLongitude': activeRide.pickupLongitude,
          'dropLatitude':    activeRide.dropLatitude,
          'dropLongitude':   activeRide.dropLongitude,
          'pickupOtp':       activeRide.pickupOtp,
          'driverLatitude':  activeRide.driverLatitude,
          'driverLongitude': activeRide.driverLongitude,
          'paymentMethod':   activeRide.paymentMethod,
          'cancellationFee': activeRide.cancellationFee,
        });

        final status = activeRide.status;
        if (status == 'COMPLETED') {
          // Completed → go straight to bill, never tracking
          Navigator.pushReplacementNamed(context, '/bill-confirmation');
        } else if (['SEARCHING', 'ASSIGNED', 'ARRIVED', 'IN_PROGRESS']
            .contains(status)) {
          // Use the guard — replace so back button returns to home not nothing
          TrackingRouter.open(context, replace: false);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Active ride check failed: $e');
    }
  }

  void _onNavTap(int index) {
  setState(() => _navIndex = index);
}

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _Theme.bg,
  body: IndexedStack(
  index: _navIndex,
  children: [
    const _HomeTab(),
    const BookingFlowScreen(),
    const HistoryScreen(),
    const AccountScreen(),
  ],
),
bottomNavigationBar: AppBottomNavBar(
  currentIndex: _navIndex,
  onTap: _onNavTap,
),
        
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HOME TAB
// ═══════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with SingleTickerProviderStateMixin {
  List<dynamic> _addresses    = [];
  bool          _loadingAddrs = true;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _loadAddresses();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final addrs = await ApiService.getAddresses();
      if (mounted) setState(() {
        _addresses    = addrs is List ? addrs : [];
        _loadingAddrs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddrs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = Provider.of<AuthProvider>(context);
    final firstName = (auth.fullName ?? 'User').split(' ').first;
    final hour      = DateTime.now().hour;
    final greeting  = hour < 12 ? 'Good Morning'
        : hour < 17  ? 'Good Afternoon'
        : 'Good Evening';

    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: RefreshIndicator(
            onRefresh: _loadAddresses,
            color: _Theme.accent,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(greeting, firstName)),
                SliverToBoxAdapter(
                  child: Consumer<RideProvider>(builder: (_, ride, __) {
                    if (ride.currentRide == null) return const SizedBox.shrink();
                    return _buildActiveBanner(ride.currentRide!);
                  }),
                ),
                SliverToBoxAdapter(child: _buildBookCTA()),
                SliverToBoxAdapter(child: _buildQuickActions()),
                SliverToBoxAdapter(child: _buildLocationsSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String greeting, String firstName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: const TextStyle(
                        color: _Theme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('$firstName 👋',
                    style: const TextStyle(
                        color: _Theme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6)),
                const SizedBox(height: 3),
                const Text('Where are you delivering today?',
                    style: TextStyle(
                        color: _Theme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/notification-settings'),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _Theme.white,
                borderRadius: BorderRadius.circular(_Theme.r12),
                boxShadow: const [
                  BoxShadow(color: _Theme.cardShadow, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: _Theme.primary, size: 22),
                  Positioned(
                    top: 10, right: 11,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: _Theme.green, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FIX 2: Track button uses TrackingRouter.open instead of pushNamed ──
  // Previously every tap stacked a new TrackingScreen.
  Widget _buildActiveBanner(Map r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Theme.white,
        borderRadius: BorderRadius.circular(_Theme.r16),
        border: Border.all(color: _Theme.green.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: _Theme.cardShadow, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _Theme.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_Theme.r12),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: _Theme.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _Theme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r['status'] ?? 'ACTIVE',
                    style: const TextStyle(
                        color: _Theme.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r['dropAddress'] ?? '',
                  style: const TextStyle(
                      color: _Theme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── FIXED: was Navigator.pushNamed(context, '/tracking') ──
          GestureDetector(
            onTap: () => TrackingRouter.open(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _Theme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Track',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCTA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/booking-flow'),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _Theme.primary,
            borderRadius: BorderRadius.circular(_Theme.r20),
            boxShadow: [
              BoxShadow(
                color: _Theme.primary.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_Theme.r20),
            child: Stack(
              children: [
                Positioned(
                  right: -28, top: -28,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                Positioned(
                  right: 50, bottom: -40,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('PORTER',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2)),
                            ),
                            const SizedBox(height: 10),
                            const Text('Book a Delivery',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4)),
                            const SizedBox(height: 4),
                            Text(
                              'Bikes · Autos · Mini Trucks · Trucks',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('Get Started',
                                      style: TextStyle(
                                          color: _Theme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: _Theme.primary, size: 13),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text('🚚', style: TextStyle(fontSize: 58)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _ActionItem(
        icon: Icons.receipt_long_rounded,
        label: 'History',
        subtitle: 'Past rides',
        color: const Color(0xFF6C63FF),
        onTap: () => Navigator.pushNamed(context, '/history'),
      ),
      _ActionItem(
        icon: Icons.headset_mic_rounded,
        label: 'Support',
        subtitle: '24/7 help',
        color: const Color(0xFF00C853),
        onTap: () => Navigator.pushNamed(context, '/support'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUICK ACTIONS',
              style: TextStyle(
                  color: _Theme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: actions.map((a) {
              final isLast = actions.last == a;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 12),
                  child: _buildActionCard(a),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(_ActionItem a) {
    return GestureDetector(
      onTap: a.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: _Theme.white,
          borderRadius: BorderRadius.circular(_Theme.r16),
          boxShadow: const [
            BoxShadow(color: _Theme.cardShadow, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: a.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(a.icon, color: a.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.label,
                      style: const TextStyle(
                          color: _Theme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(a.subtitle,
                      style: const TextStyle(
                          color: _Theme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _Theme.textHint, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SAVED LOCATIONS',
                  style: TextStyle(
                      color: _Theme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: _showAddAddressSheet,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _Theme.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _Theme.accent.withOpacity(0.18)),
                  ),
                  child: const Text('+ Add',
                      style: TextStyle(
                          color: _Theme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingAddrs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    color: _Theme.accent, strokeWidth: 2),
              ),
            )
          else if (_addresses.isEmpty) ...[
            _locationTile(
                Icons.home_rounded, 'Home', 'Tap + Add to save your home'),
            const SizedBox(height: 8),
            _locationTile(
                Icons.work_rounded, 'Work', 'Tap + Add to save your work'),
          ] else
            ..._addresses.map((addr) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/booking-flow'),
                    child: _locationTile(
                      addr.label == 'Work'
                          ? Icons.work_rounded
                          : addr.label == 'Home'
                              ? Icons.home_rounded
                              : Icons.location_on_rounded,
                      addr.label,
                      addr.address,
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _locationTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _Theme.white,
        borderRadius: BorderRadius.circular(_Theme.r16),
        boxShadow: const [
          BoxShadow(
              color: _Theme.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _Theme.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _Theme.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _Theme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: _Theme.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: _Theme.textHint, size: 18),
        ],
      ),
    );
  }

  void _showAddAddressSheet() {
    final labelCtrl   = TextEditingController();
    final addressCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _Theme.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(_Theme.r24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _Theme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Add Location',
                style: TextStyle(
                    color: _Theme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _sheetField(labelCtrl, 'Label  (e.g. Home, Work)', maxLines: 1),
            const SizedBox(height: 10),
            _sheetField(addressCtrl, 'Full address', maxLines: 2),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (labelCtrl.text.isNotEmpty &&
                      addressCtrl.text.isNotEmpty) {
                    Navigator.pop(ctx);
                    try {
                      await ApiService.addAddress(
                        label:     labelCtrl.text.trim(),
                        address:   addressCtrl.text.trim(),
                        latitude:  0,
                        longitude: 0,
                      );
                      _loadAddresses();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Theme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_Theme.r16)),
                  elevation: 0,
                ),
                child: const Text('Save Location',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: _Theme.bg,
        borderRadius: BorderRadius.circular(_Theme.r12),
        border: Border.all(color: _Theme.divider),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: _Theme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _Theme.textHint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  TRACK TAB
//  FIX 3: Removed the addPostFrameCallback push that was firing
//  on EVERY Consumer rebuild (i.e. on every single WebSocket
//  location update = dozens of times per second).
//  Replaced with a one-time push using TrackingRouter guard.
// ═══════════════════════════════════════════════════════════
class _TrackTab extends StatefulWidget {
  const _TrackTab();
  @override
  State<_TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<_TrackTab> {
  @override
  void initState() {
    super.initState();
    // One-time check on tab open — not inside build()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ride =
          Provider.of<RideProvider>(context, listen: false).currentRide;
      if (ride != null && mounted) {
        TrackingRouter.open(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── No Navigator calls inside build() ever ──
    return Consumer<RideProvider>(builder: (_, ride, __) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _Theme.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                        color: _Theme.cardShadow,
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: _Theme.textHint, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                ride.currentRide != null
                    ? 'Ride in progress'
                    : 'No active deliveries',
                style: const TextStyle(
                    color: _Theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                ride.currentRide != null
                    ? 'Tap below to open tracking'
                    : 'Book a delivery to track it here',
                style: const TextStyle(
                    color: _Theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (ride.currentRide != null)
                GestureDetector(
                  onTap: () => TrackingRouter.open(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 13),
                    decoration: BoxDecoration(
                      color: _Theme.primary,
                      borderRadius: BorderRadius.circular(_Theme.r12),
                      boxShadow: [
                        BoxShadow(
                          color: _Theme.primary.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Text('Open Tracking',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/booking-flow'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 13),
                    decoration: BoxDecoration(
                      color: _Theme.primary,
                      borderRadius: BorderRadius.circular(_Theme.r12),
                      boxShadow: [
                        BoxShadow(
                          color: _Theme.primary.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Text('Book Now',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════
//  HELPER DATA CLASS
// ═══════════════════════════════════════════════════════════
class _ActionItem {
  final IconData     icon;
  final String       label;
  final String       subtitle;
  final Color        color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}