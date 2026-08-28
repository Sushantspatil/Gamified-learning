import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';
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
    final accent = accentColor ?? colors.primary;

    return Semantics(
      label: semanticLabel ?? 'Progress',
      value: '${(clampedValue * 100).round()}%',
      child: ClipRRect(
        borderRadius: AppDimensions.radiusCircular,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: trackColor ?? colors.surfaceElevated,
            borderRadius: AppDimensions.radiusCircular,
          ),
          child: SizedBox(
            height: height,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: clampedValue),
              duration: AppMotion.duration(context, AppMotion.normal),
              curve: AppMotion.easeOut,
              builder: (context, animatedValue, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: animatedValue,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, colors.secondary],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
