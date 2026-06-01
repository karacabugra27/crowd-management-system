import 'package:flutter/material.dart';

/// Core color palette for the Crowdly Bluetooth scanner app.
/// Dark theme with neon accents for density visualization.
class AppColors {
  AppColors._();

  // ─── Base Surfaces ──────────────────────────────────────
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF14141F);
  static const Color card = Color(0xFF1C1C2E);
  static const Color cardHover = Color(0xFF242440);
  static const Color border = Color(0xFF2A2A3E);

  // ─── Typography ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFFEAEAF0);
  static const Color textSecondary = Color(0xFF8888A0);
  static const Color textTertiary = Color(0xFF5C5C72);

  // ─── Accent ─────────────────────────────────────────────
  static const Color accent = Color(0xFF6C63FF);
  static const Color accentLight = Color(0xFF8B83FF);
  static const Color accentDark = Color(0xFF4A42D4);

  // ─── Density Colors (Neon) ──────────────────────────────
  static const Color densityLow = Color(0xFF00E676);
  static const Color densityMedium = Color(0xFFFFEA00);
  static const Color densityHigh = Color(0xFFFF1744);
  static const Color densityCritical = Color(0xFFD500F9);

  // ─── Feedback ───────────────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFEA00);
  static const Color error = Color(0xFFFF1744);
  static const Color info = Color(0xFF448AFF);

  /// Returns the appropriate density color based on occupancy percentage.
  ///  - 0–50%   → Green (Low)
  ///  - 50–75%  → Yellow (Medium)
  ///  - 75–90%  → Red (High)
  ///  - 90–100% → Purple (Critical)
  static Color getDensityColor(double percentage) {
    if (percentage >= 90) return densityCritical;
    if (percentage >= 75) return densityHigh;
    if (percentage >= 50) return densityMedium;
    return densityLow;
  }

  /// Returns a human-readable label for the density level.
  static String getDensityLabel(double percentage) {
    if (percentage >= 90) return 'Critical';
    if (percentage >= 75) return 'High';
    if (percentage >= 50) return 'Medium';
    return 'Low';
  }

  /// Glowing box shadow for neon effects.
  static List<BoxShadow> neonGlow(Color color, {double intensity = 0.4, double blurRadius = 12}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: intensity),
        blurRadius: blurRadius,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: color.withValues(alpha: intensity * 0.5),
        blurRadius: blurRadius * 2,
        spreadRadius: 2,
      ),
    ];
  }
}
