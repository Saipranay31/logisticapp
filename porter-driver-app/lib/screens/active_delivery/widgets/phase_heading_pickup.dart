import 'package:flutter/material.dart';
import '../delivery_tokens.dart';
import 'delivery_common_widgets.dart';

class PhaseHeadingToPickup extends StatelessWidget {
  final bool isLoading;
  final String etaLabel;
  final VoidCallback onOpenMaps;
  final VoidCallback onArrived;

  const PhaseHeadingToPickup({
    super.key,
    required this.isLoading,
    required this.etaLabel,
    required this.onOpenMaps,
    required this.onArrived,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      hintCard(
        Icons.navigation_rounded, DT.blue,
        'Navigating to pickup',
        etaLabel.isNotEmpty ? 'ETA: $etaLabel' : 'Follow the blue route on map',
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: outlineBtn(
          'Maps', Icons.map_rounded, DT.blue, onOpenMaps)),
        const SizedBox(width: 10),
        Expanded(child: primaryBtn(
          'Arrived at Pickup', Icons.check_circle_rounded, DT.green,
          isLoading, onArrived)),
      ]),
    ]);
  }
}
