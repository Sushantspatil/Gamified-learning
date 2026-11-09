import 'package:flutter/material.dart';

import '../../../app/motion/app_motion.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/animated_count_text.dart';

/// The streak as a big flame with the day count beside it. The flame pops in
/// with a bounce (and the number counts up) whenever the screen appears, so
/// the streak feels alive. With no streak yet it is a grey, unlit flame.
///
/// It plays once instead of looping, so it never keeps a screen "busy".
class StreakFlame extends StatelessWidget {
  final int days;

  const StreakFlame({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final lit = days > 0;

    final flame = SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (lit)
            // A soft glow behind the flame.
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.streakFire.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: lit
                  ? const [
                      Color(0xFFFF3D00),
                      AppColors.streakFire,
                      AppColors.accentGold,
                    ]
                  : [colors.textSecondary, colors.textSecondary],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 68,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pop(enabled: lit, child: flame),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lit)
              AnimatedCountText(
                value: days,
                style: styles.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.streakFire,
                ),
              )
            else
              Text(
                '0',
                style: styles.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.textSecondary,
                ),
              ),
            Text(
              'day streak',
              key: const Key('streak_flame_label'),
              style: styles.labelLarge.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Scales in with a springy bounce the first time it is shown.
class _Pop extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _Pop({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled || AppMotion.reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
