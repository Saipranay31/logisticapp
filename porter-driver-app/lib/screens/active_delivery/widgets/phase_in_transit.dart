import 'package:flutter/material.dart';
import '../delivery_tokens.dart';
import 'delivery_common_widgets.dart';

class PhaseInTransit extends StatelessWidget {
  final bool isLoading;
  final double distanceTraveled;
  final VoidCallback onOpenMaps;
  final VoidCallback onArrivedAtDrop;

  const PhaseInTransit({
    super.key,
    required this.isLoading,
    required this.distanceTraveled,
    required this.onOpenMaps,
    required this.onArrivedAtDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: DT.green.withOpacity(0.08), borderRadius: DT.r12,
          border: Border.all(color: DT.green.withOpacity(0.2)),
        ),
        child: Row(children: [
          PulsingDot(color: DT.green),
          const SizedBox(width: 8),
          const Expanded(child: Text('Live location shared with customer',
            style: TextStyle(
              color: DT.green, fontSize: 11,
              fontWeight: FontWeight.w600))),
          Text('${distanceTraveled.toStringAsFixed(1)} km',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: outlineBtn(
          'Maps', Icons.map_rounded, DT.blue, onOpenMaps)),
        const SizedBox(width: 10),
        Expanded(child: primaryBtn(
          'Arrived at Drop', Icons.flag_rounded, DT.accent,
          isLoading, onArrivedAtDrop)),
      ]),
    ]);
  }
}
