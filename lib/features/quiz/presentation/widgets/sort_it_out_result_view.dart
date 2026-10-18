import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/sort_it_out_models.dart';

/// Dedicated authoritative result and learning review screen for Sort It Out.
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

    final missedCards = result.cardsReview
        .where((r) => !r.isCorrect || r.isTimeout)
        .toList(growable: false);
    final displayedCards =
        _showAllCards ? result.cardsReview : (missedCards.isEmpty ? result.cardsReview : missedCards);

    return SingleChildScrollView(
      key: const Key('sort-results-scroll'),
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sort It Out — Results',
            textAlign: TextAlign.center,
            style: context.appTextStyles.headingMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${result.correctCount} of ${result.totalQuestions} correct',
            textAlign: TextAlign.center,
            style: context.appTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 1. Authoritative Final Score Banner
          _ScoreSummaryBanner(result: result),

          const SizedBox(height: AppSpacing.md),

          // 2. Economy Rewards Tally
          _RewardTotals(
            xp: result.xpAwarded,
            coins: result.coinsAwarded,
            gems: result.gemsAwarded,
            leveledUp: result.didLevelUp,
          ),

          const SizedBox(height: AppSpacing.lg),

          // 3. Authoritative Score Breakdown
          _AuthoritativeScoreBreakdown(result: result),

          const SizedBox(height: AppSpacing.lg),

          // 4. Cards Review Section (with missed focus and full toggle)
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

          const SizedBox(height: AppSpacing.xl),

          // Actions
          if (widget.onPlayAgain != null) ...[
            AppButton(
              label: 'Play again',
              onPressed: widget.onPlayAgain,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Done',
            variant: AppButtonVariant.secondary,
            onPressed: widget.onDone,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ScoreSummaryBanner extends StatelessWidget {
  final SortItOutResult result;

  const _ScoreSummaryBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatPill(
                  label: '${result.accuracyPercentage.toStringAsFixed(0)}% Accuracy',
                  icon: Icons.track_changes_rounded,
                  color: colors.secondary,
                ),
                const SizedBox(width: AppSpacing.md),
                _StatPill(
                  label: '🔥 ${result.bestStreak} Best Streak',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.streakFire,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
            icon: Icons.diamond,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
        color: colors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const Divider(height: 18),
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
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
        ),
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
                  color: review.pointsEarned > 0 ? colors.primary : colors.textSecondary,
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
                borderRadius: BorderRadius.circular(8),
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
