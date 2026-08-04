import 'package:flutter/material.dart';
import '../delivery_tokens.dart';
import 'delivery_common_widgets.dart';

class DeliveryMapControls extends StatelessWidget {
  final bool navMode;
  final bool myLocInit;
  final VoidCallback onCenter;
  final VoidCallback onOverview;
  final VoidCallback onOpenMaps;
  final VoidCallback onBack;

  const DeliveryMapControls({
    super.key,
    required this.navMode,
    required this.myLocInit,
    required this.onCenter,
    required this.onOverview,
    required this.onOpenMaps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassBtn(
          size: 44,
          tooltip: navMode ? 'Re-center' : 'Navigate',
          onTap: onCenter,
          child: Icon(
            navMode ? Icons.navigation_rounded : Icons.my_location_rounded,
            color: DT.blue, size: 20),
        ),
        const SizedBox(height: 8),
        GlassBtn(
          size: 44,
          tooltip: 'Overview',
          onTap: onOverview,
          child: const Icon(Icons.zoom_out_map_rounded,
            color: Colors.black87, size: 18),
        ),
        const SizedBox(height: 8),
        GlassBtn(
          size: 44,
          tooltip: 'Open Maps',
          onTap: onOpenMaps,
          child: const Icon(Icons.open_in_new_rounded,
            color: Colors.black87, size: 18),
        ),
        const SizedBox(height: 8),
        GlassBtn(
          size: 44,
          tooltip: 'Back',
          onTap: onBack,
          child: const Icon(Icons.arrow_back_rounded,
            color: Colors.black87, size: 20),
        ),
      ],
    );
  }
}
