import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_theme_colors.dart';

/// A game-style meter: recessed track, glossy fill with a highlight stripe.
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
    this.height = 12,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final clampedValue = value.clamp(0.0, 1.0);
    final accent = accentColor ?? colors.primary;
    final track = trackColor ?? colors.backgroundSecondary;
    final showShine = height >= 8;

    return Semantics(
      label: semanticLabel ?? 'Progress',
      value: '${(clampedValue * 100).round()}%',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: track,
          borderRadius: AppDimensions.radiusCircular,
          border: Border.all(
            color: Color.alphaBlend(
              Colors.black.withValues(alpha: 0.18),
              track,
            ),
            width: height >= 10 ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppDimensions.radiusCircular,
          child: SizedBox(
            height: height,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: clampedValue),
              duration: AppMotion.duration(context, AppMotion.slow),
              curve: AppMotion.easeOut,
              builder: (context, animatedValue, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: animatedValue,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppDimensions.radiusCircular,
                        gradient: LinearGradient(
                          colors: [
                            accent,
                            Color.lerp(accent, colors.secondary, 0.45)!,
                          ],
                        ),
                      ),
                      child: showShine
                          ? Align(
                              alignment: const Alignment(0, -0.55),
                              child: FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: 0.28,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: height / 2,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                      borderRadius:
                                          AppDimensions.radiusCircular,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : null,
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
