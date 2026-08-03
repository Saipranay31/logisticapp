import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../models/cached_ride_data.dart';
import 'tracking_tokens.dart';
import 'tracking_shared_widgets.dart';

// ═══════════════════════════════════════════════════════════
//  DRIVER CARD WIDGET
// ═══════════════════════════════════════════════════════════

class DriverCardWidget extends StatelessWidget {
  final Map<String, dynamic> ride;
  final CachedRideData? cachedRideData;
  final VoidCallback onPhoneTap;
  final VoidCallback onChatTap;

  const DriverCardWidget({
    super.key,
    required this.ride,
    required this.cachedRideData,
    required this.onPhoneTap,
    required this.onChatTap,
  });

 @override
Widget build(BuildContext context) {
  // ── Prefer cache, fall back to ride map ───────────────
  final name    = cachedRideData?.driverName   ?? ride['driverName']   ?? 'Driver';
  final rating  = cachedRideData?.driverRating ?? (ride['driverRating'] as num?)?.toDouble();
  final vehicle = cachedRideData?.vehicleType  ?? ride['vehicleType']  ?? '';
  final plate   = cachedRideData?.vehicleNumber ?? ride['vehicleNumber'];
  final imgUrl  = AppConfig.getFileUrl(cachedRideData?.driverImage ?? ride['driverImage']);
  debugPrint('🖼️ DriverCard imgUrl="$imgUrl" raw="${cachedRideData?.driverImage ?? ride['driverImage']}"');

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TrackingTokens.offWhite,
      borderRadius: TrackingTokens.r16,
      border: Border.all(color: TrackingTokens.divider, width: 1),
    ),
    child: Row(children: [
      DriverImageAvatar(imageUrl: imgUrl, driverName: name),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  color: TrackingTokens.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 13),
            const SizedBox(width: 2),
            Text(
              rating != null ? rating.toStringAsFixed(1) : '—',
              style: const TextStyle(
                  color: TrackingTokens.inkMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(width: 3, height: 3,
                decoration: const BoxDecoration(
                    color: TrackingTokens.inkLight, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(vehicle,
                style: const TextStyle(color: TrackingTokens.inkLight, fontSize: 12)),
          ]),
          if (plate != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TrackingTokens.white,
                borderRadius: TrackingTokens.r8,
                border: Border.all(color: TrackingTokens.divider),
              ),
              child: Text(plate,
                  style: const TextStyle(
                      color: TrackingTokens.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ],
        ]),
      ),
      Row(mainAxisSize: MainAxisSize.min, children: [
        TrackingActionChip(icon: Icons.phone_rounded, onTap: onPhoneTap),
        const SizedBox(width: 8),
        TrackingActionChip(icon: Icons.chat_bubble_outline_rounded, onTap: onChatTap),
      ]),
    ]),
  );
}
}
