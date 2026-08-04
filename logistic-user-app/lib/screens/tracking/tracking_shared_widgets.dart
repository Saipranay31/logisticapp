import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'tracking_tokens.dart';

// ═══════════════════════════════════════════════════════════
//  GLASS BUTTON  (map overlays, appbar)
// ═══════════════════════════════════════════════════════════

class TrackingGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;

  const TrackingGlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ACTION CHIP  (phone / chat in driver card)
// ═══════════════════════════════════════════════════════════

class TrackingActionChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const TrackingActionChip({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TrackingTokens.white,
          borderRadius: TrackingTokens.r8,
          border: Border.all(color: TrackingTokens.divider),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Icon(icon, color: TrackingTokens.ink, size: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  RECONNECTING BADGE
// ═══════════════════════════════════════════════════════════

class ReconnectingBadge extends StatefulWidget {
  const ReconnectingBadge({super.key});

  @override
  State<ReconnectingBadge> createState() => _ReconnectingBadgeState();
}

class _ReconnectingBadgeState extends State<ReconnectingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: TrackingTokens.accentAmber, size: 12),
        const SizedBox(width: 4),
        Text('Reconnecting',
            style: TextStyle(
                color: TrackingTokens.accentAmber,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PULSING DOT
// ═══════════════════════════════════════════════════════════

class PulsingDot extends StatefulWidget {
  final Color color;

  const PulsingDot({super.key, required this.color});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
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
    _scale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1)
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DRIVER IMAGE AVATAR
// ═══════════════════════════════════════════════════════════

class DriverImageAvatar extends StatefulWidget {
  final String? imageUrl;
  final String driverName;

  const DriverImageAvatar(
      {super.key, required this.imageUrl, required this.driverName});

  @override
  State<DriverImageAvatar> createState() => _DriverImageAvatarState();
}

class _DriverImageAvatarState extends State<DriverImageAvatar> {
  bool _loaded = false, _error = false;

  @override
  void didUpdateWidget(DriverImageAvatar old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      setState(() {
        _loaded = false;
        _error = false;
      });
      _precache();
    }
  }

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so the widget is fully mounted before
    // precacheImage accesses InheritedWidgets (MediaQuery) via context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precache();
    });
  }

  void _precache() {
    if (widget.imageUrl?.isNotEmpty == true) {
      debugPrint('🖼️ _precache: attempting "${widget.imageUrl}"');
      precacheImage(NetworkImage(widget.imageUrl!), context)
          .then((_) {
            debugPrint('🖼️ _precache: ✅ loaded "${widget.imageUrl}"');
            if (mounted) setState(() => _loaded = true);
          })
          .catchError((e) {
            debugPrint('🖼️ _precache: ❌ error for "${widget.imageUrl}": $e');
            if (mounted) setState(() => _error = true);
          });
    } else {
      debugPrint('🖼️ _precache: skipped — imageUrl is null/empty');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty || _error) {
      final initials = widget.driverName.isNotEmpty
          ? widget.driverName
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
          : '?';
      return Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
            color: TrackingTokens.ink, shape: BoxShape.circle),
        child: Center(
          child: Text(initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TrackingTokens.divider, width: 1.5),
      ),
      child: ClipOval(
        child: Stack(children: [
          if (!_loaded)
            Container(
              color: TrackingTokens.offWhite,
              child: const Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: TrackingTokens.inkLight, strokeWidth: 2)),
              ),
            ),
          Image.network(
            widget.imageUrl!,
            width: 46,
            height: 46,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _error = true);
              });
              return const SizedBox.shrink();
            },
          ),
        ]),
      ),
    );
  }
}
