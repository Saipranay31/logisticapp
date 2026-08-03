import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'tracking_tokens.dart';

// ═══════════════════════════════════════════════════════════
//  MARKER ICON BUILDERS
// ═══════════════════════════════════════════════════════════

Future<BitmapDescriptor> buildVehicleIcon(String? vehicleType) async {
  try {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const s = 120.0;

    // Shadow
    c.drawCircle(
      const Offset(s / 2 + 2, s / 2 + 3),
      34,
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // White card circle
    c.drawCircle(const Offset(s / 2, s / 2), 34, Paint()..color = Colors.white);

    // Thin border
    c.drawCircle(
      const Offset(s / 2, s / 2),
      34,
      Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final emoji = switch (vehicleType) {
      'BIKE'       => '🏍️',
      'AUTO'       => '🛺',
      'MINI_TRUCK' => '🚚',
      'TRUCK'      => '🚛',
      _            => '🚗',
    };

    final tp = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 30)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset((s - tp.width) / 2, (s - tp.height) / 2 - 1));

    final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) {
      return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    }
  } catch (_) {}
  return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
}

Future<BitmapDescriptor> buildPickupIcon() async {
  try {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const w = 80.0, h = 96.0;

    final shadowPath = Path()
      ..addOval(Rect.fromCenter(
          center: const Offset(w / 2 + 2, h - 8), width: 24, height: 8));
    c.drawPath(
        shadowPath,
        Paint()
          ..color = Colors.black.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    final pinPaint = Paint()..color = TrackingTokens.accentGreen;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - 22, 0, 44, 44), const Radius.circular(12));
    c.drawRRect(rrect, pinPaint);

    final tail = Path()
      ..moveTo(w / 2 - 10, 40)
      ..lineTo(w / 2, h - 12)
      ..lineTo(w / 2 + 10, 40)
      ..close();
    c.drawPath(tail, pinPaint);

    c.drawCircle(Offset(w / 2, 22), 14, Paint()..color = Colors.white);

    final tp = TextPainter(
        text: const TextSpan(
            text: 'P',
            style: TextStyle(
                color: TrackingTokens.accentGreen,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset(w / 2 - tp.width / 2, 22 - tp.height / 2));

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
  } catch (_) {}
  return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
}

Future<BitmapDescriptor> buildDropIcon() async {
  try {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const w = 80.0, h = 96.0;

    final shadowPath = Path()
      ..addOval(Rect.fromCenter(
          center: const Offset(w / 2 + 2, h - 8), width: 24, height: 8));
    c.drawPath(
        shadowPath,
        Paint()
          ..color = Colors.black.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    final pinPaint = Paint()..color = TrackingTokens.accent;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - 22, 0, 44, 44), const Radius.circular(12));
    c.drawRRect(rrect, pinPaint);

    final tail = Path()
      ..moveTo(w / 2 - 10, 40)
      ..lineTo(w / 2, h - 12)
      ..lineTo(w / 2 + 10, 40)
      ..close();
    c.drawPath(tail, pinPaint);

    c.drawCircle(Offset(w / 2, 22), 14, Paint()..color = Colors.white);

    final tp = TextPainter(
        text: const TextSpan(
            text: 'D',
            style: TextStyle(
                color: TrackingTokens.accent,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset(w / 2 - tp.width / 2, 22 - tp.height / 2));

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
  } catch (_) {}
  return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
}
