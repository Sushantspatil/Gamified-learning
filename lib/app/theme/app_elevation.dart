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
          color: colors.shadow,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      2 => [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      _ => [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.16),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    };
  }
}
