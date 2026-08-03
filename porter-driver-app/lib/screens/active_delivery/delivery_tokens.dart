import 'package:flutter/material.dart';

/// Public design tokens for the active delivery screen.
/// Replaces the old library-private `_T` class.
class DT {
  static const bg        = Color(0xFF0A0E21);
  static const surface   = Color(0xFF1D1E33);
  static const surfaceHi = Color(0xFF252740);
  static const white     = Color(0xFFFFFFFF);
  static const divider   = Color(0xFF2A2D4A);
  static const accent    = Color(0xFFFF6B35);
  static const green     = Color(0xFF00E676);
  static const blue      = Color(0xFF4285F4);
  static const amber     = Color(0xFFFFAB40);
  static const red       = Color(0xFFFF5252);

  static List<BoxShadow> get sheetShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 32, offset: const Offset(0, -6)),
    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8,  offset: const Offset(0, -1)),
  ];

  static const r8  = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const r32 = BorderRadius.all(Radius.circular(32));
}
