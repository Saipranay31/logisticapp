import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../delivery_tokens.dart';

class DeliveryEtaBadge extends StatelessWidget {
  final String etaLabel;

  const DeliveryEtaBadge({super.key, required this.etaLabel});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DT.r20,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: DT.blue.withOpacity(0.9),
            borderRadius: DT.r20,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.access_time_rounded, color: Colors.white, size: 11),
            const SizedBox(width: 4),
            Text(etaLabel,
              style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
