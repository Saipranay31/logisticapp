import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _otpCtrls  = List.generate(6, (_) => TextEditingController());
  final _otpFocus  = List.generate(6, (_) => FocusNode());
  bool  _otpSent = false, _isLoading = false;
  int   _resendSec = 0;
  Timer? _timer;

  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static const Color _primaryBlack      = Color(0xFF000000);
  static const Color _accentBlue        = Color(0xFF276EF1);
  static const Color _scaffoldBg        = Color(0xFFFFFFFF);
  static const Color _inputBg           = Color(0xFFF6F6F6);
  static const Color _inputBorder       = Color(0xFFE0E0E0);
  static const Color _dividerColor      = Color(0xFFE8E8E8);
  static const Color _titleColor        = Color(0xFF000000);
  static const Color _subtitleColor     = Color(0xFF545454);
  static const Color _mutedText         = Color(0xFF9E9E9E);
  static const Color _otpInactiveBorder = Color(0xFFDDDDDD);

  static const double     _titleSize     = 30.0;
  static const FontWeight _titleWeight   = FontWeight.w900;
  static const double     _subtitleSize  = 14.0;
  static const double     _btnFontSize   = 16.0;
  static const FontWeight _btnFontWeight = FontWeight.w700;
  static const double     _inputRadius   = 12.0;
  static const double     _btnRadius     = 14.0;
  static const double     _otpBoxW       = 46.0;
  static const double     _otpBoxH       = 56.0;
  static const double     _otpBoxRadius  = 12.0;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (var c in _otpCtrls) c.dispose();
    for (var f in _otpFocus) f.dispose();
    _timer?.cancel();
    _slideCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _resendSec = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSec <= 0) t.cancel();
      setState(() => _resendSec--);
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneCtrl.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 10-digit phone number')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok   = await auth.sendOtp(_phoneCtrl.text.trim());
    setState(() { _isLoading = false; _otpSent = ok; });
    if (ok) {
      _startTimer();
      _otpFocus[0].requestFocus();
      _slideCtrl.forward(from: 0);
      _fadeCtrl.forward(from: 0);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed')),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 6-digit OTP')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.verifyOtp(
      _phoneCtrl.text.trim(),
      otp,
      'DRIVER',
    );
    setState(() => _isLoading = false);
    if (ok && mounted) {
      try {
        final profile = await ApiService.getDriverProfile();
        if (!mounted) return;
        if (!profile.isActive) {
          Navigator.pushReplacementNamed(context, '/suspended');
        } else if (profile.kycStatus == 'VERIFIED') {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/kyc');
        }
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString();
        // 401/403 handler already navigated — don't double-navigate
        if (msg.contains('Session expired') || msg.contains('suspended')) return;
        Navigator.pushReplacementNamed(context, '/kyc');
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid OTP. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: h * 0.30,
              width: double.infinity,
              color: _primaryBlack,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: _primaryBlack,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Porter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Driver Partner Portal',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otpSent ? 'Enter OTP' : 'Sign in',
                          style: const TextStyle(
                            color: _titleColor,
                            fontSize: _titleSize,
                            fontWeight: _titleWeight,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _otpSent
                              ? 'Code sent to +91 ${_phoneCtrl.text}'
                              : 'Enter your mobile number to continue',
                          style: const TextStyle(
                            color: _subtitleColor,
                            fontSize: _subtitleSize,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildPhoneField(),
                        if (!_otpSent) ...[
                          const SizedBox(height: 20),
                          _buildPrimaryButton('Get OTP', _sendOtp),
                          const SizedBox(height: 24),
                          _buildDivider(),
                          const SizedBox(height: 24),
                          _buildOutlineButton('Need Help?', () {}),
                        ],
                        if (_otpSent) ...[
                          const SizedBox(height: 28),
                          const Text(
                            'Verification Code',
                            style: TextStyle(
                              color: _titleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildOtpRow(),
                          const SizedBox(height: 28),
                          _buildPrimaryButton('Verify OTP', _verifyOtp),
                          const SizedBox(height: 20),
                          _buildResendRow(),
                        ],
                        const SizedBox(height: 32),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_inputRadius),
        border: Border.all(color: _inputBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _inputBorder),
            ),
            child: const Text(
              '🇮🇳  +91',
              style: TextStyle(
                color: _titleColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller:      _phoneCtrl,
              enabled:         !_otpSent,
              keyboardType:    TextInputType.phone,
              maxLength:       10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: _titleColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '00000 00000',
                hintStyle: TextStyle(
                  color: _mutedText,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 17),
              ),
            ),
          ),
          if (_otpSent)
            GestureDetector(
              onTap: () => setState(() {
                _otpSent = false;
                for (var c in _otpCtrls) c.clear();
              }),
              child: const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(Icons.edit_outlined, color: _accentBlue, size: 20),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _buildOtpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final filled = _otpCtrls[i].text.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width:  _otpBoxW,
          height: _otpBoxH,
          decoration: BoxDecoration(
            // FIX: always white background — digit is black, always visible
            color: Colors.white,
            borderRadius: BorderRadius.circular(_otpBoxRadius),
            border: Border.all(
              // Active border = black when filled, light grey when empty
              color: filled ? _primaryBlack : _otpInactiveBorder,
              width: filled ? 2.0 : 1.5,
            ),
            boxShadow: filled
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: TextField(
            controller:      _otpCtrls[i],
            focusNode:       _otpFocus[i],
            keyboardType:    TextInputType.number,
            textAlign:       TextAlign.center,
            maxLength:       1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            // FIX: text always black so it's readable on white background
            style: const TextStyle(
              color:      _primaryBlack,
              fontSize:   22,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) _otpFocus[i + 1].requestFocus();
              if (v.isEmpty   && i > 0) _otpFocus[i - 1].requestFocus();
              setState(() {});
            },
          ),
        );
      }),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:         _primaryBlack,
          disabledBackgroundColor: _primaryBlack.withOpacity(0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_btnRadius)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize:   _btnFontSize,
                  fontWeight: _btnFontWeight,
                  color:      Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildOutlineButton(String label, VoidCallback onTap) {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.headset_mic_outlined, size: 20, color: _primaryBlack),
        label: Text(
          label,
          style: const TextStyle(
            color:      _primaryBlack,
            fontSize:   _btnFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _inputBorder, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_btnRadius)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: _dividerColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: _mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _dividerColor, thickness: 1)),
      ],
    );
  }

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_resendSec > 0)
          Text(
            'Resend code in  ${_resendSec}s',
            style: const TextStyle(color: _mutedText, fontSize: 13),
          )
        else
          GestureDetector(
            onTap: _sendOtp,
            child: const Text(
              'Resend OTP',
              style: TextStyle(
                color:      _accentBlue,
                fontSize:   13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: _accentBlue,
              ),
            ),
          ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () => setState(() {
            _otpSent = false;
            for (var c in _otpCtrls) c.clear();
          }),
          child: const Text(
            'Change number',
            style: TextStyle(color: _mutedText, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'By continuing, you agree to our Terms & Conditions\nand Privacy Policy.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color:    _mutedText,
          fontSize: 12,
          height:   1.7,
        ),
      ),
    );
  }
}