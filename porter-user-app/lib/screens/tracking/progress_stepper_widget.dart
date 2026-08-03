import 'package:flutter/material.dart';
import 'tracking_tokens.dart';

// ═══════════════════════════════════════════════════════════
//  PROGRESS STEPPER WIDGET  (horizontal pill style)
// ═══════════════════════════════════════════════════════════

class ProgressStepperWidget extends StatelessWidget {
  final String status;

  const ProgressStepperWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('SEARCHING', 'Searching', Icons.search_rounded),
      ('ASSIGNED', 'Assigned', Icons.person_pin_circle_rounded),
      ('ARRIVED', 'Arrived', Icons.location_on_rounded),
      ('IN_PROGRESS', 'On the Way', Icons.local_shipping_rounded),
      ('COMPLETED', 'Delivered', Icons.check_circle_rounded),
    ];

    const allSteps = [
      'SEARCHING',
      'ASSIGNED',
      'ARRIVED',
      'IN_PROGRESS',
      'COMPLETED'
    ];
    final curIdx = allSteps.indexOf(status);
    final statusColor = TrackingTokens.statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: TrackingTokens.offWhite,
        borderRadius: TrackingTokens.r16,
      ),
      child: Row(
        children: List.generate(steps.length, (i) {
          final (stepKey, label, icon) = steps[i];
          final stepIdx = allSteps.indexOf(stepKey);
          final done = stepIdx <= curIdx;
          final isCur = stepIdx == curIdx;
          final isLast = i == steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isCur ? 34 : 28,
                      height: isCur ? 34 : 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? statusColor : TrackingTokens.divider,
                        boxShadow: isCur
                            ? [
                                BoxShadow(
                                    color: statusColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2)
                              ]
                            : [],
                      ),
                      child: Icon(icon,
                          size: isCur ? 16 : 13,
                          color:
                              done ? Colors.white : TrackingTokens.inkLight),
                    ),
                    const SizedBox(height: 5),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: done
                              ? TrackingTokens.ink
                              : TrackingTokens.inkLight,
                          fontSize: 9,
                          fontWeight: isCur
                              ? FontWeight.w700
                              : FontWeight.w500,
                        )),
                  ]),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: stepIdx < curIdx
                            ? statusColor
                            : TrackingTokens.divider,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
