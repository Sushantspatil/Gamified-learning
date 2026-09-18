import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/quiz_result.dart';
import 'quiz_celebration_overlay.dart';

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
    final xp = rewardXp ?? result.xpAwarded;
    final coins = rewardCoins ?? result.coinsAwarded;

    return QuizCelebrationOverlay(
      child: Center(
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
                      ? 'Sudden Death - Quiz Ended'
                      : result.quizType == QuestionType.sortItRight
                      ? 'Sort It Out - Results'
                      : 'Quiz Complete!',
                  style: context.appTextStyles.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                _ScorePanel(result: result),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MetricPill(
                      icon: Icons.check_circle_outline,
                      label: '${score.correctCount} correct',
                      color: colors.success,
                    ),
                    _MetricPill(
                      icon: Icons.cancel_outlined,
                      label: '${result.wrongCount} wrong',
                      color: colors.error,
                    ),
                    _MetricPill(
                      icon: Icons.track_changes_rounded,
                      label: '${(result.accuracy * 100).round()}% accuracy',
                      color: colors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _RewardTotals(xp: xp, coins: coins, leveledUp: leveledUp),
                if (result.levelProgress != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _XpProgressPanel(
                    progress: result.levelProgress!,
                    earnedXp: xp,
                  ),
                ],
                _RewardBreakdowns(result: result),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => _showScoringSheet(context),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('How scoring works'),
                ),
                const SizedBox(height: AppSpacing.lg),
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
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  final QuizResult result;

  const _ScorePanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Text('Score', style: context.appTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${result.score.earnedPoints} / ${result.score.maxPoints}',
              style: context.appTextStyles.displayMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Quiz points', style: context.appTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RewardTotals extends StatelessWidget {
  final int xp;
  final int coins;
  final bool leveledUp;

  const _RewardTotals({
    required this.xp,
    required this.coins,
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
        if (leveledUp)
          _RewardChip(
            icon: Icons.upgrade_rounded,
            color: colors.primary,
            label: 'Level up',
          ),
      ],
    );
  }
}

class _RewardBreakdowns extends StatelessWidget {
  final QuizResult result;

  const _RewardBreakdowns({required this.result});

  @override
  Widget build(BuildContext context) {
    final breakdown = result.rewardBreakdown;
    final sections = [
      if (breakdown.hasScore)
        _BreakdownSection(
          title: 'Points',
          unit: 'pts',
          color: context.themeColors.primary,
          items: breakdown.score,
        ),
      if (breakdown.hasXp)
        _BreakdownSection(
          title: 'XP earned',
          unit: 'XP',
          color: AppColors.xpPurple,
          items: breakdown.xp,
        ),
      if (breakdown.hasCoins)
        _BreakdownSection(
          title: 'Coins',
          unit: '',
          color: AppColors.coinGold,
          items: breakdown.coins,
        ),
    ];

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Text(
          'Detailed reward breakdown is unavailable for this result.',
          textAlign: TextAlign.center,
          style: context.appTextStyles.bodySmall,
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        for (final section in sections) ...[
          section,
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _XpProgressPanel extends StatelessWidget {
  final QuizLevelProgress progress;
  final int earnedXp;

  const _XpProgressPanel({required this.progress, required this.earnedXp});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.xpPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.xpPurple.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Level ${progress.currentLevel}',
                    style: context.appTextStyles.titleMedium,
                  ),
                ),
                Text(
                  '+$earnedXp XP',
                  style: context.appTextStyles.labelLarge.copyWith(
                    color: AppColors.xpPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${progress.experience} / ${progress.nextLevelExperience} XP',
              style: context.appTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.progress),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: value,
                    backgroundColor: colors.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.xpPurple,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final String title;
  final String unit;
  final Color color;
  final List<RewardBreakdownItem> items;

  const _BreakdownSection({
    required this.title,
    required this.unit,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.amount != 0).toList();
    if (visibleItems.isEmpty) return const SizedBox.shrink();

    final colors = context.themeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.appTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final item in visibleItems)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _friendlyRewardLabel(item.key),
                        style: context.appTextStyles.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '+${item.amount}${unit.isEmpty ? '' : ' $unit'}',
                      style: context.appTextStyles.labelLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
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
            Text(label, style: context.appTextStyles.labelLarge),
          ],
        ),
      ),
    );
  }
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
          _buildItem(context, index),
      ],
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final side = index < answer.selectedSides.length
        ? answer.selectedSides[index]
        : null;
    final correct = side == question.correctSides[index];
    final status = side == null
        ? 'Missed'
        : correct
        ? 'Correct'
        : 'Wrong';
    return Padding(
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
                if (!correct)
                  Text(
                    side == null
                        ? 'Missed'
                        : 'Your answer: ${question.categoryLabel(side)}',
                    style: context.appTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            correct ? Icons.check_circle_outline : Icons.cancel_outlined,
            semanticLabel: status,
            color: correct
                ? context.themeColors.success
                : context.themeColors.error,
          ),
        ],
      ),
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

String _friendlyRewardLabel(String key) {
  return switch (key) {
    'correct_answer_points' => 'Correct answers',
    'bonus_points' => 'Bonus points',
    'completion_xp' => 'Quiz completion',
    'correct_answer_xp' => 'Correct answers',
    'perfect_bonus_xp' => 'Perfect score bonus',
    'completion_coins' => 'Quiz completion',
    'accuracy_bonus_coins' => 'Accuracy bonus',
    'level_up_bonus_coins' => 'Level up bonus',
    _ =>
      key
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
  };
}

void _showScoringSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How scoring works',
                style: context.appTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              _ScoringInfoRow(
                icon: Icons.track_changes_rounded,
                title: 'Points',
                body: 'Earned from correct answers in this quiz.',
                color: context.themeColors.primary,
              ),
              _ScoringInfoRow(
                icon: Icons.bolt,
                title: 'XP',
                body: 'Helps increase your account level.',
                color: AppColors.xpPurple,
              ),
              _ScoringInfoRow(
                icon: Icons.monetization_on,
                title: 'Coins',
                body: 'Can be used for power-ups.',
                color: AppColors.coinGold,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ScoringInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _ScoringInfoRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.appTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: context.appTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
