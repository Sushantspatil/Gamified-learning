import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/quiz_result.dart';

class QuizResultView extends StatelessWidget {
  final QuizResult result;
  final int? rewardXp;
  final int? rewardCoins;
  final bool leveledUp;
  final VoidCallback onDone;

  const QuizResultView({
    super.key,
    required this.result,
    required this.onDone,
    this.rewardXp,
    this.rewardCoins,
    this.leveledUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    final colors = context.themeColors;
    final accent = result.endedEarly ? colors.error : colors.warning;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: AppCard(
          variant: AppCardVariant.tinted,
          tintColor: accent,
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: result.endedEarly
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
                  result.endedEarly ? Icons.whatshot : Icons.emoji_events,
                  color: colors.textInverse,
                  size: 44,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                result.endedEarly
                    ? 'Sudden Death — Quiz Ended'
                    : 'Quiz Complete!',
                style: context.appTextStyles.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${score.earnedPoints} / ${score.maxPoints} points',
                style: context.appTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${score.correctCount} of ${score.totalCount} correct',
                style: context.appTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _metricSummary(result),
                textAlign: TextAlign.center,
                style: context.appTextStyles.bodyMedium,
              ),
              if (rewardXp != null && rewardCoins != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _RewardChip(
                      icon: Icons.bolt,
                      color: AppColors.xpPurple,
                      label: '+$rewardXp XP',
                    ),
                    _RewardChip(
                      icon: Icons.monetization_on,
                      color: AppColors.coinGold,
                      label: '+$rewardCoins Coins',
                    ),
                  ],
                ),
              ],
              if (leveledUp) ...[
                const SizedBox(height: AppSpacing.md),
                _RewardChip(
                  icon: Icons.upgrade_rounded,
                  color: colors.primary,
                  label: 'Level up',
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Done', onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }
}

String _metricSummary(QuizResult result) {
  final accuracy = (result.accuracy * 100).round();
  return switch (result.quizType) {
    QuestionType.mcq => 'Accuracy $accuracy% · Wrong ${result.wrongCount}',
    QuestionType.matchTheFollowing =>
      'Pairs matched ${result.score.correctCount} · Accuracy $accuracy%',
    QuestionType.suddenDeath =>
      'Streak ${result.streakCount} · Questions survived ${result.streakCount}',
    QuestionType.sortItRight =>
      'Correct positions ${result.score.correctCount} · Accuracy $accuracy%',
  };
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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
            Text(label, style: context.appTextStyles.labelLarge),
          ],
        ),
      ),
    );
  }
}
