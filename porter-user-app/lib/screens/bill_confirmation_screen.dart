import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';

class BillConfirmationScreen extends StatefulWidget {
  const BillConfirmationScreen({super.key});

  @override
  State<BillConfirmationScreen> createState() => _BillConfirmationScreenState();
}

class _BillConfirmationScreenState extends State<BillConfirmationScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors (same system as all other screens) ──────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _primaryText = Color(0xFF1A1A1A);
  static const Color _green = Color(0xFF00C853);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _amber = Color(0xFFFFB300);

  // ── State (UNCHANGED logic) ────────────────────────────────────────────────
  bool _isConfirming = false;
  Map<String, dynamic>? _billDetails;
  bool _isLoading = true;
  String _selectedPayment = 'CASH';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _loadBillDetails();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Logic (UNCHANGED) ──────────────────────────────────────────────────────
  Future<void> _loadBillDetails() async {
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final ride = rideProvider.currentRide;
      if (ride == null) { _showError('No active ride found'); return; }
      final rideId = ride['id'].toString();
      final response = await ApiService.getBill(rideId);
      if (mounted) {
        setState(() { _billDetails = response; _isLoading = false; });
        _animController.forward();
      }
    } catch (e) {
      print('❌ Failed to load bill: $e');
      if (mounted) {
        _showError('Failed to load bill details: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processPayment() async {
    if (_billDetails == null) return;
    try {
      setState(() => _isConfirming = true);
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final rideId = rideProvider.currentRide!['id'].toString();
      if (_selectedPayment == 'CASH') {
        await ApiService.setPaymentMethod(rideId, 'CASH');
        await ApiService.confirmBill(rideId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('💰 Cash payment selected. Driver will confirm receipt.'),
              backgroundColor: Color(0xFF00C853),
              duration: Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pushReplacementNamed(
              context, '/payment-processing',
              arguments: rideProvider.currentRide,
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔜 Online payment coming soon! Please use cash for now.'),
              backgroundColor: Color(0xFFFF3B30),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) _showError('Payment failed: $e');
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _disputeFare() {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final ride = rideProvider.currentRide;
    Navigator.pushNamed(context, '/support', arguments: {
      'type': 'FARE_DISPUTE',
      'rideId': ride?['id'],
      'subject': 'Dispute for delivery charge',
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red,
          duration: const Duration(seconds: 3)),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _surface,
        body: Consumer<RideProvider>(
          builder: (_, rideProvider, __) {
            final ride = rideProvider.currentRide;

            if (ride == null) {
              return _buildEmptyState('No active ride found');
            }
            if (_isLoading) {
              return _buildLoadingState();
            }
            if (_billDetails == null) {
              return _buildErrorState();
            }

            return Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: _buildContent(ride),
                      ),
                    ),
                  ),
                ),
                _buildBottomActions(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12, left: 16, right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface, borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _black, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Delivery Complete',
              style: TextStyle(
                color: _primaryText, fontSize: 20,
                fontWeight: FontWeight.w800, letterSpacing: -0.5,
              ),
            ),
          ),
          // Completed badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle_rounded, color: _green, size: 13),
                SizedBox(width: 4),
                Text('Done', style: TextStyle(
                  color: _green, fontSize: 12, fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Main scrollable content ────────────────────────────────────────────────
  Widget _buildContent(Map<String, dynamic> ride) {
    final bill = _billDetails!;
    final fare = (bill['actualFare'] as num?)?.toDouble() ?? 0.0;
    final gst = fare * 0.05;
    final subtotal = fare - gst;

    return Column(
      children: [
        const SizedBox(height: 8),
        _buildSuccessBanner(fare),
        const SizedBox(height: 16),
        _buildRouteCard(bill),
        const SizedBox(height: 12),
        _buildTripStatsCard(bill, ride),
        const SizedBox(height: 12),
        _buildFareBreakdownCard(fare, subtotal, gst),
        const SizedBox(height: 12),
        _buildDriverCard(bill),
        const SizedBox(height: 12),
        _buildPaymentSelector(),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Success banner ─────────────────────────────────────────────────────────
  Widget _buildSuccessBanner(double fare) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Successful',
                  style: TextStyle(
                    color: _white, fontSize: 16, fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total amount due',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₹${fare.toStringAsFixed(0)}',
            style: const TextStyle(
              color: _white, fontSize: 28,
              fontWeight: FontWeight.w900, letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Route card ─────────────────────────────────────────────────────────────
  Widget _buildRouteCard(Map<String, dynamic> bill) {
    return _card(
      child: Column(
        children: [
          _routeRow(
            icon: Icons.circle,
            iconColor: _green,
            iconSize: 11,
            label: 'Pickup',
            address: bill['pickupAddress'] ?? 'Pickup Location',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: SizedBox(
              height: 18,
              child: CustomPaint(painter: _DottedLinePainter()),
            ),
          ),
          _routeRow(
            icon: Icons.location_on_rounded,
            iconColor: _red,
            iconSize: 18,
            label: 'Drop',
            address: bill['dropAddress'] ?? 'Drop Location',
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        SizedBox(width: 20, child: Icon(icon, color: iconColor, size: iconSize)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                color: _hint, fontSize: 10, fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              )),
              const SizedBox(height: 1),
              Text(address,
                style: const TextStyle(
                  color: _primaryText, fontSize: 13, fontWeight: FontWeight.w600,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Trip stats card ────────────────────────────────────────────────────────
  Widget _buildTripStatsCard(Map<String, dynamic> bill, Map<String, dynamic> ride) {
    return _card(
      child: Row(
        children: [
          _statItem(
            Icons.route_rounded,
            '${(bill['actualDistanceKm'] ?? 0).toStringAsFixed(1)} km',
            'Distance',
          ),
          _verticalDivider(),
          _statItem(
            Icons.local_shipping_rounded,
            ride['vehicleType'] ?? 'Vehicle',
            'Vehicle',
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _black, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(
            color: _primaryText, fontSize: 15, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _hint, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 44, color: _divider);
  }

  // ── Fare breakdown card ────────────────────────────────────────────────────
  Widget _buildFareBreakdownCard(double fare, double subtotal, double gst) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: _black, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Ride Fare',
              style: TextStyle(
                color: _hint, fontSize: 13, fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₹${fare.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _black, fontSize: 22,
              fontWeight: FontWeight.w900, letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareRow(String label, String amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: bold ? _primaryText : _hint,
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          )),
          Text(amount, style: TextStyle(
            color: bold ? _primaryText : _hint,
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          )),
        ],
      ),
    );
  }

  // ── Driver card ────────────────────────────────────────────────────────────
  Widget _buildDriverCard(Map<String, dynamic> bill) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _surface, shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: _black, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill['driverName'] ?? 'Driver',
                  style: const TextStyle(
                    color: _primaryText, fontSize: 15, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bill['driverPhone'] ?? '',
                  style: const TextStyle(color: _hint, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.star_rounded, color: _amber, size: 14),
                SizedBox(width: 3),
                Text('4.8', style: TextStyle(
                  color: _amber, fontSize: 13, fontWeight: FontWeight.w700,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment selector ───────────────────────────────────────────────────────
  Widget _buildPaymentSelector() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              color: _primaryText, fontSize: 15, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _paymentOption(
                type: 'CASH',
                icon: Icons.money_rounded,
                label: 'Cash',
                sublabel: 'Pay to driver',
              )),
              const SizedBox(width: 10),
              Expanded(child: _paymentOption(
                type: 'ONLINE',
                icon: Icons.credit_card_rounded,
                label: 'Online',
                sublabel: 'Coming soon',
                disabled: true,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String type,
    required IconData icon,
    required String label,
    required String sublabel,
    bool disabled = false,
  }) {
    final isSelected = _selectedPayment == type;
    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _selectedPayment = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? _black : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _black : _divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon,
              color: disabled
                  ? _hint
                  : isSelected ? _white : _primaryText,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
              color: disabled
                  ? _hint
                  : isSelected ? _white : _primaryText,
              fontSize: 13, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 2),
            Text(sublabel, style: TextStyle(
              color: disabled ? _hint : isSelected ? Colors.white54 : _hint,
              fontSize: 10,
            )),
          ],
        ),
      ),
    );
  }

  // ── Sticky bottom actions ──────────────────────────────────────────────────
  Widget _buildBottomActions() {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24), topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20, offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16, 16, 16, MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Dispute button
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _isConfirming ? null : _disputeFare,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _red.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.flag_rounded, color: _red, size: 16),
                          SizedBox(width: 6),
                          Text('Dispute', style: TextStyle(
                            color: _red, fontSize: 14, fontWeight: FontWeight.w700,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Pay button
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isConfirming ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _black,
                      foregroundColor: _white,
                      elevation: 4,
                      shadowColor: _black.withOpacity(0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isConfirming
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: _white, strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedPayment == 'CASH'
                                    ? Icons.money_rounded
                                    : Icons.credit_card_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedPayment == 'CASH' ? 'Pay Cash' : 'Pay Online',
                                style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _selectedPayment == 'CASH'
                ? 'Driver will confirm when cash is received'
                : 'Online payment integration coming soon',
            style: const TextStyle(color: _hint, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Empty / loading / error states ─────────────────────────────────────────
  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildTopBar(),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: _black, strokeWidth: 2.5),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Text(msg, style: const TextStyle(color: _hint, fontSize: 14)),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _surface, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      color: _hint, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Failed to load bill',
                    style: TextStyle(color: _primaryText, fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    setState(() => _isLoading = true);
                    _loadBillDetails();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Try Again',
                        style: TextStyle(color: _white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared card wrapper ────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Dotted line painter (same as booking screen) ───────────────────────────────
class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashH = 4.0;
    const gap = 3.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashH), paint);
      y += dashH + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}