import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../domain/entities/quiz_result.dart';

class QuizResultView extends StatelessWidget {
  final QuizResult result;
  final int? rewardXp;
  final int? rewardCoins;
  final bool leveledUp;
  final VoidCallback onDone;
  final VoidCallback? onPlayAgain;

  const QuizResultView({
    super.key,
    required this.result,
    required this.onDone,
    this.onPlayAgain,
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
      child: SingleChildScrollView(
        padding: AppSpacing.paddingMd,
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
                    : result.quizType == QuestionType.sortItRight
                    ? 'Sort It Out — Results'
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
              if (result.quizType == QuestionType.sortItRight) ...[
                for (final record in result.records)
                  if (record.question is SortItRightQuestion &&
                      record.answer is SortAnswer)
                    _SortAnswerReview(
                      question: record.question as SortItRightQuestion,
                      answer: record.answer as SortAnswer,
                    ),
                if (onPlayAgain != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(label: 'Play again', onPressed: onPlayAgain),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
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
      'Accuracy $accuracy% · Wrong ${result.wrongCount}',
  };
}

class _SortAnswerReview extends StatelessWidget {
  final SortItRightQuestion question;
  final SortAnswer answer;

  const _SortAnswerReview({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    if (!question.hasCategories) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Answer review', style: context.appTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 0; index < question.itemsInOrder.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.itemsInOrder[index],
                        style: context.appTextStyles.labelLarge,
                      ),
                      Text(
                        'Correct group: ${question.categoryLabel(question.correctSides[index])}',
                        style: context.appTextStyles.bodySmall,
                      ),
                      if (index < answer.selectedSides.length &&
                          answer.selectedSides[index] !=
                              question.correctSides[index])
                        Text(
                          'Your answer: ${question.categoryLabel(answer.selectedSides[index])}',
                          style: context.appTextStyles.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  index < answer.selectedSides.length &&
                          answer.selectedSides[index] ==
                              question.correctSides[index]
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  semanticLabel:
                      index < answer.selectedSides.length &&
                          answer.selectedSides[index] ==
                              question.correctSides[index]
                      ? 'Correct'
                      : 'Wrong',
                  color:
                      index < answer.selectedSides.length &&
                          answer.selectedSides[index] ==
                              question.correctSides[index]
                      ? context.themeColors.success
                      : context.themeColors.error,
                ),
              ],
            ),
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
