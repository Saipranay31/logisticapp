import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/api_service.dart';

class PaymentProcessingScreen extends StatefulWidget {
  const PaymentProcessingScreen({super.key});
  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen>
    with TickerProviderStateMixin {
  // ── Colors (same system) ───────────────────────────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _primaryText = Color(0xFF1A1A1A);
  static const Color _green = Color(0xFF00C853);
  static const Color _amber = Color(0xFFFFB300);

  // ── State (UNCHANGED logic) ────────────────────────────────────────────────
  Timer? _pollTimer;
  bool _paymentConfirmed = false;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _startPaymentPolling();
  }

  // ── Logic (UNCHANGED) ──────────────────────────────────────────────────────
  Future<void> _startPaymentPolling() async {
    final ride = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    if (ride['id'] == null) return;

    print('🔄 Starting payment polling for ride: ${ride['id']}');

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final rideData = await ApiService.getRide(ride['id'].toString());
        print('📊 PAYMENT POLL: paymentStatus=${rideData.paymentStatus}, status=${rideData.status}');

        if (mounted && rideData.paymentStatus == 'COMPLETED') {
          print('✅✅✅ PAYMENT CONFIRMED!');
          _pollTimer?.cancel();
          setState(() => _paymentConfirmed = true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Payment Confirmed by Driver!'),
                backgroundColor: Color(0xFF00C853),
                duration: Duration(seconds: 2),
              ),
            );
          }

          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/driver-rating', arguments: ride);
          }
        }
      } catch (e) {
        print('⚠️ Error polling payment: $e');
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ride = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final fareAmount = (ride['actualFare'] ?? ride['estimatedFare'] ?? 0).toStringAsFixed(0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: _surface,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // ── Pulsing icon ───────────────────────────────────────
                      _buildPulsingIcon(),
                      const SizedBox(height: 32),

                      // ── Title & subtitle ───────────────────────────────────
                      const Text(
                        'Processing Payment',
                        style: TextStyle(
                          color: _primaryText, fontSize: 26,
                          fontWeight: FontWeight.w900, letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Waiting for driver to confirm\nyour cash payment',
                        style: TextStyle(
                          color: _hint, fontSize: 15, height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // ── Fare pill ──────────────────────────────────────────
                      _buildFarePill(fareAmount),
                      const SizedBox(height: 28),

                      // ── Status card ────────────────────────────────────────
                      _buildStatusCard(),
                      const SizedBox(height: 16),

                      // ── Tip card ───────────────────────────────────────────
                      _buildTipCard(),

                      const Spacer(flex: 3),

                      // ── Continue button (shown when confirmed) ─────────────
                      if (_paymentConfirmed)
                        _buildContinueButton(ride),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingIcon() {
    return ScaleTransition(
      scale: _pulseAnim,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _black.withOpacity(0.06),
            ),
          ),
          // Inner ring
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _black.withOpacity(0.08),
            ),
          ),
          // Icon container
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _black.withOpacity(0.2),
                  blurRadius: 20, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.payment_rounded, color: _white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildFarePill(String fareAmount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: _black,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: _black.withOpacity(0.18),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.money_rounded, color: _white, size: 18),
          const SizedBox(width: 8),
          Text(
            '₹$fareAmount',
            style: const TextStyle(
              color: _white, fontSize: 22,
              fontWeight: FontWeight.w900, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'CASH',
              style: TextStyle(
                color: _white, fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Row(
        children: [
          // Spinner
          SizedBox(
            width: 44, height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 44, height: 44,
                  child: CircularProgressIndicator(
                    color: _black, strokeWidth: 2.5,
                  ),
                ),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _surface, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: _black, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver notified',
                  style: TextStyle(
                    color: _primaryText, fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Confirmation pending cash handover',
                  style: TextStyle(color: _hint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _amber.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: _amber, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Please have the exact amount ready for the driver',
              style: TextStyle(
                color: Color(0xFF7A5C00),
                fontSize: 12, fontWeight: FontWeight.w500, height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(Map<String, dynamic> ride) {
    return Column(
      children: [
        // Green confirmed badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded, color: _green, size: 14),
              SizedBox(width: 6),
              Text('Payment confirmed by driver',
                  style: TextStyle(
                    color: _green, fontSize: 12, fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              print('🚀 Manual continue to rating screen');
              Navigator.pushReplacementNamed(
                  context, '/driver-rating', arguments: ride);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _black,
              foregroundColor: _white,
              elevation: 4,
              shadowColor: _black.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.star_outline_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'Rate Your Driver',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}