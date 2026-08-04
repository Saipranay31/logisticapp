import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers & nodes (UNCHANGED) ───────────────────────────────────────
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _otpSent = false;
  bool _isLoading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Colors (matching booking/map screens) ─────────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _primaryText = Color(0xFF1A1A1A);
  static const Color _green = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    for (var c in _otpControllers) { c.dispose(); }
    for (var f in _otpFocusNodes) { f.dispose(); }
    _resendTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ── Logic (UNCHANGED) ──────────────────────────────────────────────────────
  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) { t.cancel(); }
      setState(() { _resendSeconds--; });
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid 10-digit phone number')));
      return;
    }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.sendOtp(_phoneController.text.trim());
    setState(() { _isLoading = false; _otpSent = ok; });
    if (ok) {
      _startResendTimer();
      _otpFocusNodes[0].requestFocus();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(auth.error ?? 'Failed to send OTP')));
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter complete 6-digit OTP')));
      return;
    }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.verifyOtp(
      _phoneController.text.trim(), otp, 'User',
    );
    setState(() => _isLoading = false);
    if (result != null && mounted) {
      if (result == true) {
        Navigator.pushReplacementNamed(context, '/profile-setup');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Invalid OTP'),
              backgroundColor: Colors.red));
    }
  }

  void _resetToPhone() {
    setState(() {
      _otpSent = false;
      _nameController.clear();
      for (var c in _otpControllers) { c.clear(); }
    });
    _animController.forward(from: 0);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _white,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top branding strip ─────────────────────────────────────
                    _buildTopBranding(),

                    // ── Form card ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04), end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _otpSent
                            ? _buildOtpSection(key: const ValueKey('otp'))
                            : _buildPhoneSection(key: const ValueKey('phone')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBranding() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _black,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _black.withOpacity(0.18),
                  blurRadius: 20, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: _white, size: 32,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Porter',
            style: TextStyle(
              color: _primaryText, fontSize: 34,
              fontWeight: FontWeight.w900, letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Deliver anything, anywhere',
            style: TextStyle(
              color: _hint, fontSize: 15, fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 28),
          // Safety badge — consistent with booking screen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_user_rounded, color: _green, size: 13),
                SizedBox(width: 4),
                Text(
                  'Secure & verified',
                  style: TextStyle(
                    color: _green, fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter your phone number',
          style: TextStyle(
            color: _primaryText, fontSize: 18,
            fontWeight: FontWeight.w800, letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'We\'ll send you a verification code',
          style: TextStyle(color: _hint, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Phone input card
        _buildPhoneField(),
        const SizedBox(height: 16),
        _buildPrimaryButton('Get OTP', _sendOtp),
        const SizedBox(height: 24),
        _buildTermsText(),
      ],
    );
  }

  Widget _buildOtpSection({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with back option
        Row(
          children: [
            GestureDetector(
              onTap: _resetToPhone,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _divider),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: _black, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verify your number',
                    style: TextStyle(
                      color: _primaryText, fontSize: 18,
                      fontWeight: FontWeight.w800, letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'Code sent to +91 ${_phoneController.text}',
                    style: const TextStyle(color: _hint, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // OTP boxes
       Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: List.generate(6, (i) => Expanded(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: _buildOtpBox(i),
    ),
  )),
),
        const SizedBox(height: 24),
        _buildPrimaryButton('Verify & Continue', _verifyOtp),
        const SizedBox(height: 20),

        // Resend row
        Center(
          child: _resendSeconds > 0
              ? RichText(
                  text: TextSpan(
                    text: 'Resend code in ',
                    style: const TextStyle(color: _hint, fontSize: 13),
                    children: [
                      TextSpan(
                        text: '${_resendSeconds}s',
                        style: const TextStyle(
                          color: _primaryText, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: _sendOtp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _divider),
                    ),
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: _primaryText, fontSize: 13, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider, width: 1),
      ),
      child: Row(
        children: [
          // Country prefix
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                const Text(
                  '+91',
                  style: TextStyle(
                    color: _primaryText, fontSize: 15, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 22, color: _divider),
              ],
            ),
          ),
          // Number input
          Expanded(
            child: TextField(
              controller: _phoneController,
              enabled: !_otpSent,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: _primaryText, fontSize: 17,
                fontWeight: FontWeight.w600, letterSpacing: 1.5,
              ),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '00000 00000',
                hintStyle: TextStyle(
                  color: _hint, fontSize: 17, fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                ),
                filled: true,
                fillColor: Colors.white,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildOtpBox(int i) {
  final isFilled = _otpControllers[i].text.isNotEmpty;
  return AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    height: 54,
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isFilled ? _black : _divider,
        width: isFilled ? 1.5 : 1,
      ),
    ),
    child: TextField(
      controller: _otpControllers[i],
      focusNode: _otpFocusNodes[i],
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 1,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        color: _primaryText,
        fontSize: 20, fontWeight: FontWeight.w800,
      ),
      decoration: const InputDecoration(
        counterText: '', border: InputBorder.none,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (v) {
        if (v.isNotEmpty && i < 5) _otpFocusNodes[i + 1].requestFocus();
        if (v.isEmpty && i > 0) _otpFocusNodes[i - 1].requestFocus();
        setState(() {});
      },
    ),
  );
}
 
  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _black,
          foregroundColor: _white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 4,
          shadowColor: _black.withOpacity(0.25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: _white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Center(
      child: Text(
        'By continuing, you agree to our Terms of Service\nand Privacy Policy',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _hint, fontSize: 11, height: 1.6,
        ),
      ),
    );
  }
}