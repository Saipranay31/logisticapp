import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../delivery_tokens.dart';
import 'delivery_common_widgets.dart';

class DeliveryBottomSheet extends StatelessWidget {
  final Animation<double> animation;
  final String userName;
  final String userPhone;
  final double? userRating;
  final double fare;
  final String status;
  final String pickupAddress;
  final String dropAddress;
  final double bottomPadding;
  final VoidCallback onChat;
  final Widget phaseContent;

  const DeliveryBottomSheet({
    super.key,
    required this.animation,
    required this.userName,
    required this.userPhone,
    this.userRating,
    required this.fare,
    required this.status,
    required this.pickupAddress,
    required this.dropAddress,
    required this.bottomPadding,
    required this.onChat,
    required this.phaseContent,
  });

  String _statusLabel() => switch (status) {
    'HEADING_TO_PICKUP' => 'Navigating to pickup',
    'AT_PICKUP'         => 'At pickup — enter OTP',
    'IN_TRANSIT'        => 'En route to drop-off',
    'COMPLETED'         => 'Delivery complete',
    _                   => 'Active Delivery',
  };

  Color _statusColor() => switch (status) {
    'HEADING_TO_PICKUP' => DT.blue,
    'AT_PICKUP'         => DT.amber,
    'IN_TRANSIT'        => DT.accent,
    'COMPLETED'         => DT.green,
    _                   => Colors.white54,
  };

  @override
  Widget build(BuildContext context) {
    final initials = userName.trim().isEmpty
        ? 'C'
        : userName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 60 * (1 - animation.value)),
        child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: DT.sheetShadow,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: DT.divider,
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Customer row ────────────────────────────────────────────
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: DT.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: DT.accent.withOpacity(0.3)),
                  ),
                  child: Center(child: Text(initials,
                    style: const TextStyle(
                      color: DT.accent, fontSize: 14,
                      fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 15)),
                    if (userRating != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                        const SizedBox(width: 3),
                        Text(userRating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.amber, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                      ]),
                    ] else ...[
                      Text(_statusLabel(), style: TextStyle(
                        color: _statusColor(), fontSize: 11,
                        fontWeight: FontWeight.w600)),
                    ],
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: DT.green.withOpacity(0.1), borderRadius: DT.r12,
                    border: Border.all(color: DT.green.withOpacity(0.25)),
                  ),
                  child: Text('₹${fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: DT.green, fontWeight: FontWeight.w800,
                      fontSize: 15)),
                ),
                const SizedBox(width: 8),
                // Phone + Chat buttons
                Row(children: [
                  GestureDetector(
                    onTap: () async {
                      if (userPhone.isEmpty) return;
                      final uri = Uri.parse('tel:$userPhone');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: DT.green.withOpacity(0.1),
                        borderRadius: DT.r12,
                        border: Border.all(color: DT.green.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.phone_rounded,
                        color: DT.green, size: 17),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onChat,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: DT.blue.withOpacity(0.1),
                        borderRadius: DT.r12,
                        border: Border.all(color: DT.blue.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.chat_rounded,
                        color: DT.blue, size: 17),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),

              // ── Route mini-card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: DT.surfaceHi, borderRadius: DT.r12),
                child: Column(children: [
                  addrRow(Icons.radio_button_checked, DT.green,
                    'PICKUP', pickupAddress),
                  Padding(
                    padding: const EdgeInsets.only(left: 9),
                    child: Container(
                      width: 1.5, height: 14, color: DT.divider)),
                  addrRow(Icons.location_on_rounded, DT.red,
                    'DROP', dropAddress),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Phase content ────────────────────────────────────────────
              phaseContent,
            ]),
          ),
        ]),
      ),
    );
  }
}
