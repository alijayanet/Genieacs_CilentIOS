import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF070E1A);
  static const Color backgroundDark = Color(0xFF070E1A);
  static const Color backgroundCard = Color(0xFF132238);
  static const Color backgroundElevated = Color(0xFF182942);
  static const Color surface = Color(0xFF0F1B2D);
  static const Color surfaceLight = Color(0xFF182942);
  static const Color card = Color(0xFF132238);

  // Accents
  static const Color cyan = Color(0xFF00E5FF);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color emerald = Color(0xFF00E676);
  static const Color accentEmerald = Color(0xFF00E676);
  static const Color blue = Color(0xFF2979FF);
  static const Color accentBlue = Color(0xFF2979FF);
  static const Color amber = Color(0xFFFFB300);
  static const Color red = Color(0xFFFF3D00);

  // Signal Indicators
  static const Color signalIdeal = Color(0xFF00E676);    // >= -24.0 dBm
  static const Color signalGood = Color(0xFF00E676);
  static const Color signalWarning = Color(0xFFFFB300);  // -24.1 ~ -27.0 dBm
  static const Color signalCritical = Color(0xFFFF3D00); // < -27.0 dBm
  static const Color signalBad = Color(0xFFFF3D00);
  static const Color signalUnknown = Color(0xFF78909C);

  // Text Colors
  static const Color textPrimary = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF90A4AE);
  static const Color textMuted = Color(0xFF546E7A);

  // Borders & Glow
  static const Color border = Color(0xFF203653);
  static const Color cardBorder = Color(0xFF203653);
  static const Color borderCyan = Color(0x6600E5FF);
}
