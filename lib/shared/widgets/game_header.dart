import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/app_typography.dart';
import 'app_progress_bar.dart';

/// The header every game mode shares: the mode's name on the left, the coin
/// balance and the question counter on the right, and a thin progress bar
/// underneath. There is no back arrow: leaving is done with the phone's back
/// gesture, which asks first (see `confirmQuitGame`).
class GameHeader extends StatelessWidget {
  /// "MCQ Quiz", "Sort It Out", "Match It", "Sudden Death".
  final String title;
  final int coins;

  /// Zero-based index of the current question (shown as index + 1).
  final int currentIndex;
  final int totalQuestions;

  /// 0..1; animates smoothly when it changes.
  final double progress;
  final String? semanticLabel;

  const GameHeader({
    super.key,
    required this.title,
    required this.coins,
    required this.currentIndex,
    required this.totalQuestions,
    required this.progress,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final shown = totalQuestions == 0
        ? 0
        : (currentIndex + 1).clamp(1, totalQuestions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.titleLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // The coins and counter never take more than 62% of the row; on
              // a narrow phone or with large text they shrink to fit instead of
              // overflowing.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.62,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CoinBadge(coins: coins),
                      const SizedBox(width: AppSpacing.sm),
                      Semantics(
                        label: 'Question $shown of $totalQuestions',
                        child: AnimatedSwitcher(
                          duration: AppMotion.duration(context, AppMotion.fast),
                          child: Text(
                            '$shown / $totalQuestions',
                            key: ValueKey(shown),
                            style: context.appTextStyles.labelLarge.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: progress),
          duration: AppMotion.duration(context, AppMotion.normal),
          curve: AppMotion.easeOut,
          builder: (context, value, child) {
            return AppProgressBar(
              value: value,
              height: 8,
              accentColor: colors.primary,
              trackColor: colors.primary.withValues(alpha: 0.10),
              semanticLabel: semanticLabel ?? '$title progress',
            );
          },
        ),
      ],
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final int coins;

  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(alpha: 0.12),
        borderRadius: AppDimensions.radiusSm,
        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: AppColors.coinGold,
            size: 16,
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.fast),
            child: Text(
              '$coins',
              key: ValueKey(coins),
              style: context.appTextStyles.labelLarge.copyWith(
                color: AppColors.coinGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
