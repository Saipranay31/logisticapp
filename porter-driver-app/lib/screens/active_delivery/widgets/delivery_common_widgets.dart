import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../delivery_tokens.dart';

// ── Glass Button ─────────────────────────────────────────────────────────────

class GlassBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  const GlassBtn({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 44,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
              ],
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

// ── Pulsing Dot ──────────────────────────────────────────────────────────────

class PulsingDot extends StatefulWidget {
  final Color color;
  const PulsingDot({super.key, required this.color});
  @override State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: 5, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

// ── GPS Loading Indicator ────────────────────────────────────────────────────

class GpsLoadingIndicator extends StatelessWidget {
  const GpsLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: DT.surface.withOpacity(0.95),
          borderRadius: DT.r20,
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(color: DT.blue, strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Getting your location....',
            style: TextStyle(
              color: Colors.white70, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class DeliveryEmptyState extends StatelessWidget {
  const DeliveryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.local_shipping_outlined,
            color: Colors.white24, size: 48),
        const SizedBox(height: 16),
        const Text('No active delivery',
          style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: DT.accent,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: DT.r12),
            elevation: 0),
          child: const Text('Go Back',
            style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Shared small builder helpers ─────────────────────────────────────────────

Widget addrRow(IconData icon, Color color, String label, String address) {
  return Row(children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: const TextStyle(
          color: Colors.white30, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      Text(address,
        style: const TextStyle(color: Colors.white70, fontSize: 12,
          fontWeight: FontWeight.w500),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
  ]);
}

Widget hintCard(IconData icon, Color color, String title, String subtitle) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07), borderRadius: DT.r12,
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: DT.r8),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(subtitle, style: const TextStyle(
          color: Colors.white54, fontSize: 11)),
      ])),
    ]),
  );
}

Widget primaryBtn(
  String label, IconData icon, Color color,
  bool isLoading, VoidCallback onTap,
) {
  return SizedBox(
    width: double.infinity, height: 48,
    child: ElevatedButton.icon(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.35),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: DT.r12),
        elevation: 0,
      ),
      icon: isLoading
        ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Icon(icon, size: 17),
      label: Text(label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    ),
  );
}

Widget outlineBtn(
  String label, IconData icon, Color color, VoidCallback onTap,
) {
  return SizedBox(
    height: 48,
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: DT.r12),
      ),
      icon: Icon(icon, size: 15),
      label: Text(label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    ),
  );
}

Widget earningsRow(String label, String sub, String amount) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: const TextStyle(
          color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600)),
        Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ]),
      const SizedBox(width: 8),
      Text(amount, style: const TextStyle(
        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}
