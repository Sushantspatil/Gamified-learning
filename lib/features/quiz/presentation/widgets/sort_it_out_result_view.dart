import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/sort_it_out_models.dart';
import 'quiz_celebration_overlay.dart';

/// Dedicated authoritative result and learning review screen for Sort It Out.
///
/// Designed to follow the unified SkillVerse result screen design system used
/// across MCQ and Sudden Death modes (`QuizResultView`), providing celebratory
/// particle atmosphere, centered card structure, score presentation, metric
/// pills, reward tallies, authoritative breakdown, and card reviews.
class SortItOutResultView extends StatefulWidget {
  final SortItOutResult result;
  final VoidCallback onDone;
  final VoidCallback? onPlayAgain;

  const SortItOutResultView({
    super.key,
    required this.result,
    required this.onDone,
    this.onPlayAgain,
  });

  @override
  State<SortItOutResultView> createState() => _SortItOutResultViewState();
}

class _SortItOutResultViewState extends State<SortItOutResultView> {
  bool _showAllCards = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final result = widget.result;

    final wrongCount = result.totalQuestions > result.correctCount
        ? result.totalQuestions - result.correctCount
        : 0;

    final bool isUnsuccessful =
        result.totalQuestions > 0 && result.correctCount == 0;
    final bool isPerfect =
        !isUnsuccessful &&
        result.accuracyPercentage >= 100.0 &&
        result.correctCount == result.totalQuestions &&
        result.totalQuestions > 0;

    final celebrationType = isUnsuccessful
        ? CelebrationType.subdued
        : (isPerfect ? CelebrationType.perfect : CelebrationType.standard);

    final accent = isUnsuccessful ? colors.error : colors.warning;

    final missedCards = result.cardsReview
        .where((r) => !r.isCorrect || r.isTimeout)
        .toList(growable: false);
    final displayedCards = _showAllCards
        ? result.cardsReview
        : (missedCards.isEmpty ? result.cardsReview : missedCards);

    return GameCelebrationOverlay(
      key: ValueKey('sort-celebration-${result.session}'),
      type: celebrationType,
      child: Center(
        child: SingleChildScrollView(
          key: const Key('sort-results-scroll'),
          padding: AppSpacing.paddingMd,
          child: AppCard(
            variant: AppCardVariant.tinted,
            tintColor: accent,
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Emblem Badge (Matches MCQ & Sudden Death)
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
                  'Sort It Out — Results',
                  style: context.appTextStyles.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${result.correctCount} of ${result.totalQuestions} correct',
                  style: context.appTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // 3. Official Score Banner
                _ScorePanel(result: result),
                const SizedBox(height: AppSpacing.md),

                // 4. Metric Pills Row (Matches MCQ & Sudden Death pill design)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MetricPill(
                      icon: Icons.check_circle_outline,
                      label: '${result.correctCount} correct',
                      color: colors.success,
                    ),
                    _MetricPill(
                      icon: Icons.cancel_outlined,
                      label: '$wrongCount wrong',
                      color: colors.error,
                    ),
                    _MetricPill(
                      icon: Icons.track_changes_rounded,
                      label:
                          '${result.accuracyPercentage.toStringAsFixed(0)}% Accuracy',
                      color: colors.primary,
                    ),
                    if (result.bestStreak > 0)
                      _MetricPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '🔥 ${result.bestStreak} Best Streak',
                        color: AppColors.streakFire,
                      ),
                    if (result.timeoutCount > 0)
                      _MetricPill(
                        icon: Icons.timer_off_outlined,
                        label: '${result.timeoutCount} timeouts',
                        color: colors.warning,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Economy Reward Totals (XP, Coins, Gems, Level Up)
                _RewardTotals(
                  xp: result.xpAwarded,
                  coins: result.coinsAwarded,
                  gems: result.gemsAwarded,
                  leveledUp: result.didLevelUp,
                ),
                const SizedBox(height: AppSpacing.lg),

                // 6. Authoritative Score Breakdown Section
                _AuthoritativeScoreBreakdown(result: result),
                const SizedBox(height: AppSpacing.lg),

                // 7. Cards Review Section (with missed filter toggle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Answer review',
                      style: context.appTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (missedCards.isNotEmpty &&
                        missedCards.length < result.cardsReview.length)
                      TextButton(
                        onPressed: () {
                          setState(() => _showAllCards = !_showAllCards);
                        },
                        child: Text(
                          _showAllCards ? 'Show missed only' : 'View all cards',
                          style: TextStyle(color: colors.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                for (final review in displayedCards)
                  _CardReviewTile(review: review),

                const SizedBox(height: AppSpacing.lg),

                // 8. Actions
                if (widget.onPlayAgain != null) ...[
                  AppButton(label: 'Play again', onPressed: widget.onPlayAgain),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppButton(
                  label: 'Done',
                  variant: widget.onPlayAgain != null
                      ? AppButtonVariant.secondary
                      : AppButtonVariant.primary,
                  onPressed: widget.onDone,
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
  final SortItOutResult result;

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
  final bool leveledUp;

  const _RewardTotals({
    required this.xp,
    required this.coins,
    required this.gems,
    required this.leveledUp,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

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
        if (leveledUp)
          _RewardChip(
            icon: Icons.upgrade_rounded,
            color: colors.primary,
            label: 'Level Up!',
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
  final SortItOutResult result;

  const _AuthoritativeScoreBreakdown({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

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
              value: '+${result.basePoints}',
              color: colors.textSecondary,
            ),
            const SizedBox(height: 6),
            _BreakdownRow(
              label: 'Speed Bonus',
              value: '+${result.speedBonus}',
              color: colors.secondary,
            ),
            const SizedBox(height: 6),
            _BreakdownRow(
              label: 'Combo Bonus',
              value: '+${result.comboBonus}',
              color: AppColors.streakFire,
            ),
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

class _CardReviewTile extends StatelessWidget {
  final SortItOutCardReview review;

  const _CardReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final isCorrect = review.isCorrect;
    final isTimeout = review.isTimeout;

    final statusText = isTimeout
        ? 'Time\'s Up'
        : isCorrect
        ? 'Correct'
        : 'Wrong';

    final statusColor = isTimeout
        ? colors.warning
        : isCorrect
        ? colors.success
        : colors.error;

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
              Icon(
                isCorrect
                    ? Icons.check_circle_outline
                    : isTimeout
                    ? Icons.timer_off_outlined
                    : Icons.cancel_outlined,
                color: statusColor,
                semanticLabel: statusText,
                size: 20,
              ),
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
                    const SizedBox(height: 2),
                    Text(
                      'Correct: ${review.correctOption.toUpperCase()}',
                      style: context.appTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (!isCorrect)
                      Text(
                        isTimeout
                            ? 'Your answer: Time\'s Up'
                            : 'Your answer: ${review.selectedOption.toUpperCase()}',
                        style: context.appTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '+${review.pointsEarned} pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: review.pointsEarned > 0
                      ? colors.primary
                      : colors.textSecondary,
                ),
              ),
            ],
          ),
          if (review.explanation != null && review.explanation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
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
