import 'package:flutter/material.dart';
import '../delivery_tokens.dart';
import 'delivery_common_widgets.dart';

class PhaseCompleted extends StatelessWidget {
  final Map<String, dynamic> ride;
  final double fare;
  final double distanceTraveled;
  final double timeElapsed;
  final double distanceCharge;
  final double timeCharge;
  final int customerRating;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onComplete;
  final Future<void> Function(String rideId) onConfirmCash;

  const PhaseCompleted({
    super.key,
    required this.ride,
    required this.fare,
    required this.distanceTraveled,
    required this.timeElapsed,
    required this.distanceCharge,
    required this.timeCharge,
    required this.customerRating,
    required this.onRatingChanged,
    required this.onComplete,
    required this.onConfirmCash,
  });

  @override
  Widget build(BuildContext context) {
    final isCash   = ride['paymentMethod'] == 'CASH';
    final paidCash = ride['paymentStatus'] == 'COMPLETED';

    return Column(children: [

      // ── Earnings summary card ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            DT.green.withOpacity(0.15),
            DT.accent.withOpacity(0.08)]),
          borderRadius: DT.r16,
          border: Border.all(color: DT.green.withOpacity(0.3)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle, color: DT.green, size: 28),
            const SizedBox(height: 4),
            const Text('EARNED', style: TextStyle(
              color: Colors.white54, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            Text('₹${fare.toStringAsFixed(0)}', style: const TextStyle(
              color: DT.green, fontSize: 28,
              fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            earningsRow('Distance',
              '${distanceTraveled.toStringAsFixed(1)} km',
              '₹${distanceCharge.toStringAsFixed(0)}'),
            earningsRow('Time',
              '${(timeElapsed / 60).toStringAsFixed(0)} min',
              '₹${timeCharge.toStringAsFixed(0)}'),
          ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Cash confirmation ──────────────────────────────────────────────────
      if (isCash && !paidCash) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DT.amber.withOpacity(0.07), borderRadius: DT.r12,
            border: Border.all(color: DT.amber, width: 1.5),
          ),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.currency_rupee_rounded, color: DT.amber, size: 18),
              const SizedBox(width: 8),
              Text('Did you receive ₹${fare.toStringAsFixed(0)} cash?',
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700,
                  fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: () => onConfirmCash(ride['id'].toString()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.green, foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(borderRadius: DT.r8)),
                child: const Text('Yes, received',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⏳ Waiting for payment...'))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: DT.divider),
                  shape: const RoundedRectangleBorder(borderRadius: DT.r8)),
                child: const Text('Not yet',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
      ],

      // ── Star rating ───────────────────────────────────────────────────────
      if (!isCash || paidCash) ...[
        const Text('Rate Customer',
          style: TextStyle(
            color: Colors.white54, fontSize: 12, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
            onTap: () => onRatingChanged(i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                i < customerRating
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
                color: i < customerRating ? Colors.amber : Colors.white24,
                size: 36,
              ),
            ),
          )),
        ),
        const SizedBox(height: 12),
      ],

      primaryBtn(
        'Complete & Go Home', Icons.home_rounded, DT.accent,
        false, onComplete),
    ]);
  }
}
