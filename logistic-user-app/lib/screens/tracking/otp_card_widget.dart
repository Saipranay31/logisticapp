import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tracking_tokens.dart';

// ═══════════════════════════════════════════════════════════
//  OTP CARD WIDGET
// ═══════════════════════════════════════════════════════════

class OtpCardWidget extends StatelessWidget {
  final String? otp;
  final int otpTimeRemaining;

  const OtpCardWidget({
    super.key,
    required this.otp,
    required this.otpTimeRemaining,
  });

  String _fmtOtp() {
    final m = otpTimeRemaining ~/ 60, s = otpTimeRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final expiring = otpTimeRemaining <= 60;
    final timerColor =
        expiring ? TrackingTokens.accentAmber : TrackingTokens.accentGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrackingTokens.accentGreen.withOpacity(0.05),
        borderRadius: TrackingTokens.r16,
        border: Border.all(
            color: TrackingTokens.accentGreen.withOpacity(0.25), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: TrackingTokens.accentGreen,
              borderRadius: TrackingTokens.r8,
            ),
            child: const Text('OTP',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Share with driver to confirm pickup',
              style: TextStyle(color: TrackingTokens.inkMid, fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: timerColor.withOpacity(0.1),
              borderRadius: TrackingTokens.r8,
              border: Border.all(color: timerColor.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined, color: timerColor, size: 12),
              const SizedBox(width: 4),
              Text(_fmtOtp(),
                  style: TextStyle(
                      color: timerColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [ui.FontFeature.tabularFigures()])),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text(
              otp ?? '----',
              style: const TextStyle(
                color: TrackingTokens.ink,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: otp ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('OTP copied to clipboard'),
                backgroundColor: TrackingTokens.accentGreen,
                behavior: SnackBarBehavior.floating,
                shape: const RoundedRectangleBorder(
                    borderRadius: TrackingTokens.r12),
                duration: const Duration(seconds: 2),
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TrackingTokens.offWhite,
                borderRadius: TrackingTokens.r12,
                border: Border.all(color: TrackingTokens.divider),
              ),
              child: const Icon(Icons.copy_rounded,
                  size: 18, color: TrackingTokens.inkMid),
            ),
          ),
        ]),
      ]),
    );
  }
}
