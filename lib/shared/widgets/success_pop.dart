import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_theme_colors.dart';

class SuccessPop extends StatelessWidget {
  final Widget child;
  final bool active;

  const SuccessPop({
    super.key,
    required this.child,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    final colors = context.themeColors;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: active ? 0 : 1, end: active ? 1 : 0),
      duration: AppMotion.celebration,
      curve: AppMotion.easeOut,
      builder: (context, value, child) {
        final pulse = active ? (1 + (0.035 * (1 - (value - 0.5).abs() * 2).clamp(0.0, 1.0))) : 1.0;

        return Transform.scale(
          scale: pulse,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: colors.success.withValues(alpha: 0.18 * (1 - value)),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
