import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../delivery_tokens.dart';
import 'delivery_common_widgets.dart';

class DeliveryStatusPill extends StatelessWidget {
  final String status;
  final double fare;

  const DeliveryStatusPill({
    super.key,
    required this.status,
    required this.fare,
  });

  Color _statusColor() => switch (status) {
    'HEADING_TO_PICKUP' => DT.blue,
    'AT_PICKUP'         => DT.amber,
    'IN_TRANSIT'        => DT.accent,
    'COMPLETED'         => DT.green,
    _                   => Colors.white54,
  };

  String _statusLabel() => switch (status) {
    'HEADING_TO_PICKUP' => 'Navigating to pickup',
    'AT_PICKUP'         => 'At pickup — enter OTP',
    'IN_TRANSIT'        => 'En route to drop-off',
    'COMPLETED'         => 'Delivery complete',
    _                   => 'Active Delivery',
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return ClipRRect(
      borderRadius: DT.r32,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: DT.surface.withOpacity(0.92),
            borderRadius: DT.r32,
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(children: [
            PulsingDot(color: color),
            const SizedBox(width: 8),
            Text(_statusLabel(),
              style: TextStyle(
                color: color, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            const Spacer(),
            Text('₹${fare.toStringAsFixed(0)}',
              style: const TextStyle(
                color: DT.green, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}
