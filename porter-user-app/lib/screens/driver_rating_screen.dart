import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';

class DriverRatingScreen extends StatefulWidget {
  const DriverRatingScreen({super.key});
  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen>
    with SingleTickerProviderStateMixin {
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
  int _rating = 0;
  final _feedbackCtrl = TextEditingController();
  bool _isSubmitting = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Logic (UNCHANGED) ──────────────────────────────────────────────────────
  Future<void> _submitRating(String rideId) async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a star rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      print('📤 Submitting driver rating: $rideId, rating=$_rating');
      await ApiService.rateRide(rideId, _rating, review: _feedbackCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Color(0xFF00C853),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        print('🧹 Clearing completed ride from provider...');
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        rideProvider.clearRide();
        print('✅ Ride cleared - navigating to home');
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('❌ Error submitting rating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ride = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        children: [
                          _buildCompletionBanner(ride),
                          const SizedBox(height: 16),
                          _buildDriverCard(ride),
                          const SizedBox(height: 16),
                          _buildRatingCard(ride),
                          const SizedBox(height: 24),
                          _buildSubmitButton(ride),
                          const SizedBox(height: 12),
                          _buildSkipButton(ride),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top > 0 ? 8 : 12,
        bottom: 12, left: 16, right: 16,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Rate Your Driver',
              style: TextStyle(
                color: _primaryText, fontSize: 20,
                fontWeight: FontWeight.w800, letterSpacing: -0.5,
              ),
            ),
          ),
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
                Text('Completed', style: TextStyle(
                  color: _green, fontSize: 12, fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Completion banner ──────────────────────────────────────────────────────
  Widget _buildCompletionBanner(Map<String, dynamic> ride) {
    final fare = (ride['actualFare'] ?? ride['estimatedFare'] ?? 0).toStringAsFixed(0);
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
            child: const Icon(Icons.local_shipping_rounded, color: _white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Trip Completed!',
                  style: TextStyle(
                    color: _white, fontSize: 16, fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your delivery was successful',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$fare',
                style: const TextStyle(
                  color: _white, fontSize: 22,
                  fontWeight: FontWeight.w900, letterSpacing: -0.5,
                ),
              ),
              const Text(
                'Paid',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Driver card ────────────────────────────────────────────────────────────
  Widget _buildDriverCard(Map<String, dynamic> ride) {
    final driverName = ride['driverName'] ?? 'Driver';
    final initial = driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          // Avatar with initial
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _divider, width: 1.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: _primaryText, fontSize: 24,
                  fontWeight: FontWeight.w800,
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
                  driverName,
                  style: const TextStyle(
                    color: _primaryText, fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ride['vehicleType'] ?? 'Vehicle',
                  style: const TextStyle(color: _hint, fontSize: 13),
                ),
              ],
            ),
          ),
          // Static rating badge
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

  // ── Rating card ────────────────────────────────────────────────────────────
  Widget _buildRatingCard(Map<String, dynamic> ride) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          const Text(
            'How was your experience?',
            style: TextStyle(
              color: _primaryText, fontSize: 16,
              fontWeight: FontWeight.w800, letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your feedback helps improve the service',
            style: TextStyle(color: _hint, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < _rating ? _amber : _divider,
                    size: 44,
                  ),
                ),
              );
            }),
          ),

          // Rating label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _rating > 0
                ? Padding(
                    key: ValueKey(_rating),
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _ratingLabel(_rating),
                        style: const TextStyle(
                          color: _amber, fontSize: 13, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey(0), height: 10),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _divider),
          const SizedBox(height: 20),

          // Feedback field
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _divider, width: 1),
            ),
            child: TextField(
              controller: _feedbackCtrl,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(
                color: _primaryText, fontSize: 13, height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Share your feedback (optional)…',
                hintStyle: const TextStyle(color: _hint, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle: const TextStyle(color: _hint, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return '😞  Poor';
      case 2: return '😐  Fair';
      case 3: return '🙂  Good';
      case 4: return '😊  Great';
      case 5: return '🤩  Excellent!';
      default: return '';
    }
  }

  // ── Buttons ────────────────────────────────────────────────────────────────
  Widget _buildSubmitButton(Map<String, dynamic> ride) {
    return SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting
            ? null
            : () => _submitRating(ride['id']?.toString() ?? ''),
        style: ElevatedButton.styleFrom(
          backgroundColor: _black,
          foregroundColor: _white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 4,
          shadowColor: _black.withOpacity(0.25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: _white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Submit & Go Home',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSkipButton(Map<String, dynamic> ride) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: TextButton(
        onPressed: _isSubmitting
            ? null
            : () {
                final rideProvider = Provider.of<RideProvider>(context, listen: false);
                rideProvider.clearRide();
                Navigator.pushReplacementNamed(context, '/home');
              },
        style: TextButton.styleFrom(
          foregroundColor: _hint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          'Skip for now',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}