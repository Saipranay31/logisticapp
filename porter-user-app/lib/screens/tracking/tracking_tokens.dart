import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════

class TrackingTokens {
  // Core palette
  static const white      = Color(0xFFFFFFFF);
  static const offWhite   = Color(0xFFF6F6F6);
  static const cardBg     = Color(0xFFFFFFFF);
  static const sheetBg    = Color(0xFFF7F8FA);
  static const ink        = Color(0xFF111111);
  static const inkMid     = Color(0xFF555555);
  static const inkLight   = Color(0xFF999999);
  static const divider    = Color(0xFFEEEEEE);

  // Accent
  static const accent      = Color(0xFF000000);
  static const accentBlue  = Color(0xFF276EF1);
  static const accentGreen = Color(0xFF05944F);
  static const accentAmber = Color(0xFFFF6B00);

  // Status
  static const statusSearching = Color(0xFFFF6B00);
  static const statusAssigned  = Color(0xFF276EF1);
  static const statusArrived   = Color(0xFF05944F);
  static const statusProgress  = Color(0xFF000000);
  static const statusCompleted = Color(0xFF05944F);

  // Shadow helpers
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 4)),
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6,  offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> get softShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2)),
  ];

  // Radius
  static const r4  = BorderRadius.all(Radius.circular(4));
  static const r8  = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const r32 = BorderRadius.all(Radius.circular(32));

  // Status helpers
  static Color statusColor(String s) => switch (s) {
    'SEARCHING'   => statusSearching,
    'ASSIGNED'    => statusAssigned,
    'ARRIVED'     => statusArrived,
    'IN_PROGRESS' => statusProgress,
    'COMPLETED'   => statusCompleted,
    _             => inkLight,
  };

  static String statusLabel(String s) => switch (s) {
    'SEARCHING'   => 'Finding your driver...',
    'ASSIGNED'    => 'Driver on the way',
    'ARRIVED'     => 'Driver at pickup',
    'IN_PROGRESS' => 'On the way to destination',
    'COMPLETED'   => 'Delivered!',
    _             => s,
  };
}
