import 'package:flutter/material.dart';

import 'app_theme_colors.dart';

class AppElevation {
  AppElevation._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
  static const double level3 = 6;

  static List<BoxShadow> shadows(AppThemeColors colors, int level) {
    return switch (level) {
      0 => const [],
      1 => [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      2 => [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      _ => [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.26),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    };
  }

  /// A solid, unblurred edge under a surface that makes it look raised like a
  /// game button. Pair with [edgeColor] for the matching darker shade.
  static List<BoxShadow> raised(
    Color edge, {
    double depth = 4,
    AppThemeColors? colors,
  }) {
    return [
      BoxShadow(color: edge, offset: Offset(0, depth)),
      if (colors != null)
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.16),
          blurRadius: 14,
          offset: Offset(0, depth + 6),
        ),
    ];
  }

  /// Soft colored halo for highlighted elements (active tabs, rewards).
  static List<BoxShadow> glow(Color color, {double strength = 1}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.45 * strength),
        blurRadius: 22 * strength,
        spreadRadius: -2,
      ),
    ];
  }

  /// The darker shade of [color] used for its raised edge.
  static Color edgeColor(Color color, {double amount = 0.32}) {
    return Color.lerp(color, Colors.black, amount)!;
  }
}
