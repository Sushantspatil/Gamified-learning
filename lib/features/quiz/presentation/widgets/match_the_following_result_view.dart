import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/network/dtos/quiz_dtos.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/match_the_following_models.dart';
import 'quiz_celebration_overlay.dart';

/// Screen displayed after completing a Match the Following session with backend-authoritative data.
///
/// Designed to follow the unified SkillVerse result screen design system used
/// across MCQ and Sudden Death modes (`QuizResultView`) as well as `SortItOutResultView`,
/// providing celebratory particle atmosphere, centered card structure, top emblem,
/// score presentation, metric pills, reward tallies, authoritative breakdown,
/// board reviews, and standard action buttons.
class MatchTheFollowingResultView extends StatelessWidget {
  final MatchTheFollowingResult result;
  final VoidCallback onDone;
  final VoidCallback? onPlayAgain;

  const MatchTheFollowingResultView({
    super.key,
    required this.result,
    required this.onDone,
    this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    final bool isUnsuccessful =
        result.totalPairsCount > 0 && result.totalPairsMatched == 0;
    final bool isPerfect =
        !isUnsuccessful &&
        result.accuracyPercentage >= 100.0 &&
        result.totalPairsMatched == result.totalPairsCount &&
        result.totalPairsCount > 0 &&
        result.totalMistakes == 0;

    final celebrationType = isUnsuccessful
        ? CelebrationType.subdued
        : (isPerfect ? CelebrationType.perfect : CelebrationType.standard);

    final accent = isUnsuccessful ? colors.error : colors.warning;

    return GameCelebrationOverlay(
      key: ValueKey('match-celebration-${result.session}'),
      type: celebrationType,
      child: Center(
        child: SingleChildScrollView(
          key: const Key('match-results-scroll'),
          padding: AppSpacing.paddingMd,
          child: AppCard(
            variant: AppCardVariant.tinted,
            tintColor: accent,
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Emblem Badge (Matches MCQ, Sudden Death, and Sort It Out)
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isUnsuccessful
                          ? [colors.error, colors.violet]
                          : [colors.warning, AppColors.accentGold],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Icon(
                    isUnsuccessful ? Icons.whatshot : Icons.emoji_events,
                    color: colors.textInverse,
                    size: 44,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Title & Subtitle
                Text(
                  'Match the Following — Results',
                  style: context.appTextStyles.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${result.clearedBoards} of ${result.totalBoards} boards cleared',
                  style: context.appTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // 3. Official Score Banner
                _ScorePanel(result: result),
                const SizedBox(height: AppSpacing.md),

                // 4. Metric Pills Row (Matches MCQ & Sort It Out pill design)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MetricPill(
                      icon: Icons.check_circle_outline,
                      label:
                          '${result.totalPairsMatched} / ${result.totalPairsCount} pairs',
                      color: colors.success,
                    ),
                    _MetricPill(
                      icon: Icons.dashboard_customize_outlined,
                      label:
                          '${result.clearedBoards} / ${result.totalBoards} boards',
                      color: colors.primary,
                    ),
                    _MetricPill(
                      icon: Icons.track_changes_rounded,
                      label:
                          '${result.accuracyPercentage.toStringAsFixed(0)}% Accuracy',
                      color: colors.secondary,
                    ),
                    if (result.totalMistakes > 0)
                      _MetricPill(
                        icon: Icons.cancel_outlined,
                        label: '${result.totalMistakes} mistakes',
                        color: colors.error,
                      ),
                    if (result.streak != null &&
                        result.streak!.currentStreak > 0)
                      _MetricPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '🔥 ${result.streak!.currentStreak} Streak',
                        color: AppColors.streakFire,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Economy Reward Totals (XP, Coins, Gems, Level Up)
                _RewardTotals(
                  xp: result.xpAwarded,
                  coins: result.coinsAwarded,
                  gems: result.gemsAwarded,
                  level: result.level,
                  levelUpReward: result.levelUpReward,
                ),
                const SizedBox(height: AppSpacing.lg),

                // 6. Authoritative Score Breakdown Section
                _AuthoritativeScoreBreakdown(result: result),
                const SizedBox(height: AppSpacing.lg),

                // 7. Board Review Section
                if (result.boardsReview.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Board review',
                      style: context.appTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final item in result.boardsReview)
                    _BoardReviewCard(review: item),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 8. Action Buttons
                if (onPlayAgain != null) ...[
                  AppButton(label: 'Play again', onPressed: onPlayAgain),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppButton(
                  label: 'Done',
                  variant: onPlayAgain != null
                      ? AppButtonVariant.secondary
                      : AppButtonVariant.primary,
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  final MatchTheFollowingResult result;

  const _ScorePanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.52),
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Text('Official Score', style: context.appTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${result.finalScore}',
              style: context.appTextStyles.displayMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Points earned', style: context.appTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: context.appTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardTotals extends StatelessWidget {
  final int xp;
  final int coins;
  final int gems;
  final LevelProgressDto? level;
  final LevelUpRewardDto? levelUpReward;

  const _RewardTotals({
    required this.xp,
    required this.coins,
    required this.gems,
    this.level,
    this.levelUpReward,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final didLevelUp = level?.didLevelUp == true || levelUpReward != null;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        _RewardChip(
          icon: Icons.bolt,
          color: AppColors.xpPurple,
          label: '+$xp XP',
        ),
        _RewardChip(
          icon: Icons.monetization_on,
          color: AppColors.coinGold,
          label: '+$coins Coins',
        ),
        if (gems > 0)
          _RewardChip(
            icon: Icons.diamond_outlined,
            color: colors.secondary,
            label: '+$gems Gems',
          ),
        if (didLevelUp)
          _RewardChip(
            icon: Icons.upgrade_rounded,
            color: colors.primary,
            label: level?.current != null
                ? 'Level ${level!.current} Up!'
                : 'Level Up!',
          ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _RewardChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: context.appTextStyles.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthoritativeScoreBreakdown extends StatelessWidget {
  final MatchTheFollowingResult result;

  const _AuthoritativeScoreBreakdown({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final basePts = result.scoreBreakdown['base_points'] ?? 0;
    final flawlessBonus = result.scoreBreakdown['flawless_bonus'] ?? 0;
    final speedBonus = result.scoreBreakdown['speed_bonus'] ?? 0;
    final mistakePenalty = result.scoreBreakdown['mistake_penalty'] ?? 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Score Breakdown',
              style: context.appTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _BreakdownRow(
              label: 'Base Points',
              value: '+$basePts',
              color: colors.textSecondary,
            ),
            const SizedBox(height: 6),
            _BreakdownRow(
              label: 'Flawless Bonus',
              value: '+$flawlessBonus',
              color: colors.success,
            ),
            const SizedBox(height: 6),
            _BreakdownRow(
              label: 'Speed Bonus',
              value: '+$speedBonus',
              color: colors.secondary,
            ),
            if (mistakePenalty != 0) ...[
              const SizedBox(height: 6),
              _BreakdownRow(
                label: 'Mistake Penalty',
                value: '-${mistakePenalty.abs()}',
                color: colors.error,
              ),
            ],
            Divider(height: 18, color: colors.border.withValues(alpha: 0.3)),
            _BreakdownRow(
              label: 'Final Score',
              value: '${result.finalScore}',
              color: colors.primary,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
      fontSize: isBold ? 15 : 13,
      color: color,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle),
        Text(value, style: textStyle),
      ],
    );
  }
}

class _BoardReviewCard extends StatelessWidget {
  final MatchBoardReview review;

  const _BoardReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (review.isFlawless) {
      statusText = 'Flawless';
      statusColor = colors.success;
      statusIcon = Icons.stars_rounded;
    } else if (review.isTimeout) {
      statusText = "Time's Up";
      statusColor = colors.error;
      statusIcon = Icons.timer_off_outlined;
    } else if (review.pairsMatched == review.totalPairs) {
      statusText = 'Cleared';
      statusColor = colors.primary;
      statusIcon = Icons.check_circle_outline;
    } else {
      statusText = 'Partial';
      statusColor = colors.warning;
      statusIcon = Icons.rule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.52),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.prompt,
                      style: context.appTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Pairs: ${review.pairsMatched}/${review.totalPairs}',
                          style: context.appTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          'Mistakes: ${review.mistakes}',
                          style: context.appTextStyles.bodySmall.copyWith(
                            color: review.mistakes == 0
                                ? colors.success
                                : colors.error,
                          ),
                        ),
                        Text(
                          'Time: ${(review.timeTakenMs / 1000).toStringAsFixed(1)}s',
                          style: context.appTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: context.appTextStyles.labelSmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${review.totalBoardScore} pts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: review.totalBoardScore > 0
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (review.explanation != null && review.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.5),
                borderRadius: AppDimensions.radiusSm,
              ),
              child: Text(
                review.explanation!,
                style: context.appTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
