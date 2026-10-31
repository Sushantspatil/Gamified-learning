import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/match_the_following_models.dart';

/// Screen displayed after completing a Match the Following session with backend-authoritative data.
class MatchTheFollowingResultView extends StatelessWidget {
  final MatchTheFollowingResult result;
  final VoidCallback onDone;

  const MatchTheFollowingResultView({
    super.key,
    required this.result,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final textStyles = context.appTextStyles;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, colors, textStyles),
              const SizedBox(height: AppSpacing.lg),
              _buildMetricsGrid(context, colors, textStyles),
              const SizedBox(height: AppSpacing.lg),
              _buildScoreBreakdown(context, colors, textStyles),
              const SizedBox(height: AppSpacing.lg),
              _buildBoardReview(context, colors, textStyles),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Done', onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppThemeColors colors,
    AppTextStyles textStyles,
  ) {
    return AppCard(
      variant: AppCardVariant.surface,
      borderRadius: AppDimensions.radiusCard,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Match the Following — Results',
            style: textStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Official Score',
            style: textStyles.bodySmall.copyWith(
              color: colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${result.finalScore}',
            style: textStyles.headingLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              _RewardBadge(
                label: '+${result.xpAwarded} XP',
                color: AppColors.xpPurple,
                icon: Icons.bolt_rounded,
              ),
              _RewardBadge(
                label: '+${result.coinsAwarded} Coins',
                color: AppColors.coinGold,
                icon: Icons.monetization_on_rounded,
              ),
              if (result.gemsAwarded > 0)
                _RewardBadge(
                  label: '+${result.gemsAwarded} Gems',
                  color: AppColors.gemCyan,
                  icon: Icons.diamond_rounded,
                ),
              if (result.level?.didLevelUp == true)
                _RewardBadge(
                  label: 'Level ${result.level?.current ?? ''} Up!',
                  color: colors.success,
                  icon: Icons.military_tech_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    AppThemeColors colors,
    AppTextStyles textStyles,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                label: 'Boards Cleared',
                value: '${result.clearedBoards} / ${result.totalBoards}',
                icon: Icons.dashboard_customize_rounded,
                color: colors.primary,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                label: 'Pairs Matched',
                value:
                    '${result.totalPairsMatched} / ${result.totalPairsCount}',
                icon: Icons.check_circle_rounded,
                color: colors.success,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                label: 'Accuracy',
                value: '${result.accuracyPercentage.toStringAsFixed(1)}%',
                icon: Icons.analytics_rounded,
                color: colors.secondary,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                label: 'Mistakes',
                value: '${result.totalMistakes}',
                icon: Icons.error_outline_rounded,
                color: result.totalMistakes == 0
                    ? colors.success
                    : colors.error,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScoreBreakdown(
    BuildContext context,
    AppThemeColors colors,
    AppTextStyles textStyles,
  ) {
    final basePts = result.scoreBreakdown['base_points'] ?? 0;
    final flawlessBonus = result.scoreBreakdown['flawless_bonus'] ?? 0;
    final speedBonus = result.scoreBreakdown['speed_bonus'] ?? 0;
    final mistakePenalty = result.scoreBreakdown['mistake_penalty'] ?? 0;

    return AppCard(
      variant: AppCardVariant.surface,
      borderRadius: AppDimensions.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score Breakdown',
            style: textStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _BreakdownRow(
            label: 'Base Points',
            value: '+$basePts',
            valueColor: colors.textPrimary,
          ),
          _BreakdownRow(
            label: 'Flawless Bonus',
            value: '+$flawlessBonus',
            valueColor: colors.success,
          ),
          _BreakdownRow(
            label: 'Speed Bonus',
            value: '+$speedBonus',
            valueColor: colors.success,
          ),
          if (mistakePenalty != 0)
            _BreakdownRow(
              label: 'Mistake Penalty',
              value: '-${mistakePenalty.abs()}',
              valueColor: colors.error,
            ),
          const Divider(height: AppSpacing.lg),
          _BreakdownRow(
            label: 'Final Score',
            value: '${result.finalScore}',
            valueColor: colors.primary,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBoardReview(
    BuildContext context,
    AppThemeColors colors,
    AppTextStyles textStyles,
  ) {
    if (result.boardsReview.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Board review',
          style: textStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in result.boardsReview) ...[
          _BoardReviewCard(review: item),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _RewardBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: textStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final textStyles = context.appTextStyles;
    return AppCard(
      variant: AppCardVariant.surface,
      borderRadius: AppDimensions.radiusMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: textStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: textStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isBold;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final textStyles = context.appTextStyles;
    final style = isBold
        ? textStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)
        : textStyles.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style.copyWith(color: colors.textSecondary)),
          Text(
            value,
            style: style.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardReviewCard extends StatelessWidget {
  final MatchBoardReview review;

  const _BoardReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final textStyles = context.appTextStyles;

    final String statusText;
    final Color statusColor;

    if (review.isFlawless) {
      statusText = 'Flawless';
      statusColor = colors.success;
    } else if (review.isTimeout) {
      statusText = "Time's Up";
      statusColor = colors.error;
    } else if (review.pairsMatched == review.totalPairs) {
      statusText = 'Cleared';
      statusColor = colors.primary;
    } else {
      statusText = 'Partial';
      statusColor = colors.warning;
    }

    return AppCard(
      variant: AppCardVariant.surface,
      borderRadius: AppDimensions.radiusMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.prompt,
                  style: textStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: AppDimensions.radiusCard,
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusText,
                  style: textStyles.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            children: [
              Text(
                'Pairs: ${review.pairsMatched}/${review.totalPairs}',
                style: textStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                'Mistakes: ${review.mistakes}',
                style: textStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                'Time: ${(review.timeTakenMs / 1000).toStringAsFixed(1)}s',
                style: textStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '+${review.totalBoardScore} pts',
                style: textStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          if (review.explanation != null && review.explanation!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.explanation!,
              style: textStyles.bodySmall.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
