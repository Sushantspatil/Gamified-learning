import 'package:flutter/material.dart';

import '../../../../../app/motion/app_motion.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../../app/theme/app_typography.dart';

/// One dot per question: a green tick for a right answer, a red cross for a
/// wrong one, so the player sees at a glance how the game went. The dots pop in
/// one after another. With [onTap] the whole strip opens the answer review.
class AnswerStrip extends StatelessWidget {
  /// Right (true) or wrong (false), in the order asked.
  final List<bool> flags;
  final VoidCallback? onTap;

  const AnswerStrip({super.key, required this.flags, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) return const SizedBox.shrink();
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final reduce = AppMotion.reduceMotion(context);
    final right = flags.where((f) => f).length;

    final dots = Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < flags.length; i++)
          _Dot(correct: flags[i], delay: reduce ? 0 : i, key: Key('dot_$i')),
      ],
    );

    final strip = Column(
      key: const Key('answer_strip'),
      mainAxisSize: MainAxisSize.min,
      children: [
        dots,
        const SizedBox(height: AppSpacing.sm),
        if (onTap != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Review your answers',
                style: styles.labelLarge.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.primary,
                size: 20,
              ),
            ],
          )
        else
          Text(
            '$right of ${flags.length} right',
            style: styles.labelLarge.copyWith(color: colors.textSecondary),
          ),
      ],
    );

    if (onTap == null) return strip;
    return InkWell(
      key: const Key('answer_strip_tap'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: strip,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool correct;
  final int delay;

  const _Dot({super.key, required this.correct, required this.delay});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final color = correct ? colors.success : colors.error;
    final dot = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        correct ? Icons.check_rounded : Icons.close_rounded,
        size: 16,
        color: color,
      ),
    );
    if (AppMotion.reduceMotion(context)) return dot;
    // Each dot starts a little after the one before it.
    final begin = (delay * 0.05).clamp(0.0, 0.7);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delay * 50),
      curve: Interval(begin, 1, curve: Curves.elasticOut),
      builder: (context, t, child) =>
          Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
      child: dot,
    );
  }
}
