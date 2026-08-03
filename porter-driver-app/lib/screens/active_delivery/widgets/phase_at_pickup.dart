import 'package:flutter/material.dart';
import '../delivery_tokens.dart';
import 'delivery_common_widgets.dart';

class PhaseAtPickup extends StatelessWidget {
  final bool isLoading;
  final TextEditingController otpCtrl;
  final VoidCallback onVerifyOtp;

  const PhaseAtPickup({
    super.key,
    required this.isLoading,
    required this.otpCtrl,
    required this.onVerifyOtp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      hintCard(
        Icons.lock_rounded, DT.amber,
        'Enter OTP from customer',
        'Ask customer for the 4-digit OTP',
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: DT.surfaceHi, borderRadius: DT.r12,
          border: Border.all(color: DT.amber.withOpacity(0.3)),
        ),
        child: TextField(
          controller: otpCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
            color: Colors.black, fontSize: 28,
            letterSpacing: 10, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 28, letterSpacing: 10),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      const SizedBox(height: 10),
      primaryBtn(
        'Verify OTP & Start Trip', Icons.play_arrow_rounded, DT.accent,
        isLoading, onVerifyOtp),
    ]);
  }
}
