import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_theme_colors.dart';

class AppProgressBar extends StatelessWidget {
  final double value;
  final Color? accentColor;
  final Color? trackColor;
  final double height;
  final String? semanticLabel;

  const AppProgressBar({
    super.key,
    required this.value,
    this.accentColor,
    this.trackColor,
    this.height = 8,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final clampedValue = value.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel ?? 'Progress',
      value: '${(clampedValue * 100).round()}%',
      child: ClipRRect(
        borderRadius: AppDimensions.radiusCircular,
        child: LinearProgressIndicator(
          value: clampedValue,
          minHeight: height,
          backgroundColor: trackColor ?? colors.surfaceElevated,
          color: accentColor ?? colors.primary,
        ),
      ),
    );
  }
}
