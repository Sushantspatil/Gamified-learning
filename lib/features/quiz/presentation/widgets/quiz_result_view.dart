import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/result_outcome.dart';
import 'quiz_celebration_overlay.dart';
import 'result/game_result_flow.dart';
import 'result/answer_review_sheet.dart';
import 'result/answer_strip.dart';
import 'result/personal_best_badge.dart';
import '../../domain/result_answers.dart';
import '../../domain/result_flow.dart';
import 'result/result_share.dart';
import 'result/result_summary.dart';

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

  /// A short, safe identifier for storing this mode's best score.
  String get _modeKey =>
      result.endedEarly ? 'sudden_death' : result.quizType.name;

  String get _shareModeName => result.endedEarly
      ? 'Sudden Death'
      : result.quizType == QuestionType.sortItRight
      ? 'Sort It Out'
      : 'the MCQ Quiz';

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final score = result.score;
    final xp = rewardXp ?? result.xpAwarded;
    final coins = rewardCoins ?? result.coinsAwarded;

    final bool isUnsuccessful =
        result.endedEarly ||
        (result.completedSuccessfully == false) ||
        (score.totalCount > 0 && score.correctCount == 0);
    final bool isPerfect =
        !isUnsuccessful &&
        score.percentage >= 1.0 &&
        score.correctCount == score.totalCount &&
        score.totalCount > 0;
    final celebrationType = isUnsuccessful
        ? CelebrationType.subdued
        : (isPerfect ? CelebrationType.perfect : CelebrationType.standard);

    final outcome = outcomeFor(
      endedEarly: result.endedEarly,
      correct: score.correctCount,
      total: score.totalCount,
    );
    final accent = resultAccent(
      context,
      outcome: outcome,
      accuracy: result.accuracy,
      fiery: result.endedEarly,
    );

    final reviewItems = reviewItemsFor(result);
    Widget summaryFor(String? playerName) => ResultSummary(
      outcome: outcome,
      accent: accent,
      playerName: playerName,
      eyebrow: result.endedEarly ? 'RUN OVER' : 'ROUND COMPLETE',
      points: score.earnedPoints,
      maxPoints: score.maxPoints,
      coins: coins,
      tiles: [
        ResultTileData.number(
          label: 'XP',
          icon: Icons.bolt_rounded,
          color: AppColors.xpPurple,
          number: xp,
          prefix: '+',
        ),
        if (result.endedEarly)
          ResultTileData.number(
            label: 'CORRECT',
            icon: Icons.check_circle_rounded,
            color: colors.success,
            number: score.correctCount,
          )
        else
          ResultTileData.number(
            label: 'ACCURACY',
            icon: Icons.track_changes_rounded,
            color: colors.success,
            number: (result.accuracy * 100).round(),
            suffix: '%',
          ),
        ResultTileData.text(
          label: 'TIME',
          icon: Icons.timer_rounded,
          color: colors.info,
          text: formatResultTime(result.timeTaken),
        ),
      ],
      bestBadge: PersonalBestBadge(
        modeKey: _modeKey,
        score: score.earnedPoints,
      ),
      // A dot for every answer; tapping it opens the review, when there are
      // answers to review.
      answers: AnswerStrip(
        flags: answerFlags(result),
        onTap: reviewItems.isEmpty
            ? null
            : () => showAnswerReview(context, reviewItems),
      ),
      mascot: resultMascotFor(
        context,
        unsuccessful: isUnsuccessful,
        accuracy: result.accuracy,
        fiery: result.endedEarly,
      ),
    );

    return GameResultFlow(
      sessionKey: result.sessionId,
      celebrationType: celebrationType,
      summary: WithPlayerName(builder: summaryFor),
      levelProgress: result.levelProgress,
      earnedXp: xp,
      leveledUp: leveledUp,
      shareMessage: shareMessage(
        modeName: _shareModeName,
        score: score.earnedPoints,
        maxScore: score.maxPoints,
      ),
      onDone: onDone,
      onPlayAgain: onPlayAgain,
      onDetails: (context) => _showResultDetails(context, result),
    );
  }
}

/// The reward breakdown, and for the old Sort It Out result the answer review,
/// in a sheet that slides up from the bottom.
void _showResultDetails(BuildContext context, QuizResult result) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SingleChildScrollView(
        key: const Key('result_details_sheet'),
        controller: controller,
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Score details',
              style: context.appTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            _RewardBreakdowns(result: result),
            TextButton.icon(
              onPressed: () => _showScoringSheet(context, result.quizType),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('How scoring works'),
            ),
            if (result.quizType == QuestionType.sortItRight) ...[
              const SizedBox(height: AppSpacing.md),
              for (final record in result.records)
                if (record.question is SortItRightQuestion &&
                    record.answer is SortAnswer)
                  _SortAnswerReview(
                    question: record.question as SortItRightQuestion,
                    answer: record.answer as SortAnswer,
                  ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    ),
  );
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
          items: result.quizType == QuestionType.mcq
              ? breakdown.xp
                    .where((item) => item.key != 'speed_bonus_xp')
                    .toList(growable: false)
              : breakdown.xp,
        ),
      if (breakdown.hasCoins)
        _BreakdownSection(
          title: 'Coins',
          unit: '',
          color: AppColors.coinGold,
          items: result.quizType == QuestionType.mcq
              ? breakdown.coins
                    .where((item) => item.key != 'accuracy_bonus_coins')
                    .toList(growable: false)
              : breakdown.coins,
        ),
      if (breakdown.hasLevelUp)
        _BreakdownSection(
          title: 'Level up bonus',
          unit: '',
          color: context.themeColors.primary,
          items: breakdown.levelUp,
          formatAmount: _formatLevelUpAmount,
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

class _BreakdownSection extends StatelessWidget {
  final String title;
  final String unit;
  final Color color;
  final List<RewardBreakdownItem> items;
  final String Function(RewardBreakdownItem item)? formatAmount;

  const _BreakdownSection({
    required this.title,
    required this.unit,
    required this.color,
    required this.items,
    this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.amount != 0).toList();
    if (visibleItems.isEmpty) return const SizedBox.shrink();

    final colors = context.themeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppDimensions.radiusMd,
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
                      formatAmount?.call(item) ??
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

String _friendlyRewardLabel(String key) {
  return switch (key) {
    'correct_answer_points' => 'Correct answers',
    'bonus_points' => 'Bonus points',
    'completion_xp' => 'Quiz completion',
    'correct_answer_xp' => 'Correct answers',
    'perfect_bonus_xp' => 'Perfect score bonus',
    'speed_bonus_xp' => 'Speed bonus XP',
    'completion_coins' => 'Quiz completion',
    'correct_answer_coins' => 'Correct answers',
    'perfect_bonus_coins' => 'Perfect score bonus',
    'accuracy_bonus_coins' => 'Accuracy bonus',
    'level_up_bonus_xp' => 'XP',
    'level_up_bonus_coins' => 'Coins',
    'level_up_bonus_gems' => 'Gems',
    _ =>
      key
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
  };
}

String _formatLevelUpAmount(RewardBreakdownItem item) {
  final unit = switch (item.key) {
    'level_up_bonus_xp' => ' XP',
    'level_up_bonus_coins' => ' Coins',
    'level_up_bonus_gems' => ' Gems',
    _ => '',
  };
  return '+${item.amount}$unit';
}

void _showScoringSheet(BuildContext context, QuestionType quizType) {
  final isMcq = quizType == QuestionType.mcq;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
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
                  title: isMcq ? 'Quiz points' : 'Points',
                  body: isMcq
                      ? '+10 points for every correct answer.\n'
                            'Wrong and skipped answers give 0 points.'
                      : 'Earned from correct answers in this quiz.',
                  color: context.themeColors.primary,
                ),
                _ScoringInfoRow(
                  icon: Icons.bolt,
                  title: 'XP',
                  body: isMcq
                      ? '+10 XP for completing the quiz.\n'
                            '+5 XP for every correct answer.\n'
                            '+15 XP bonus for a perfect score.'
                      : 'Helps increase your account level.',
                  color: AppColors.xpPurple,
                ),
                _ScoringInfoRow(
                  icon: Icons.monetization_on,
                  title: 'Coins',
                  body: isMcq
                      ? '+5 Coins for completing the quiz.\n'
                            '+2 Coins for every correct answer.\n'
                            '+10 Coins bonus for a perfect score.'
                      : 'Can be used for power-ups.',
                  color: AppColors.coinGold,
                ),
                if (isMcq)
                  _ScoringInfoRow(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Power-ups',
                    body: 'Using a power-up does not reduce your score or XP.',
                    color: context.themeColors.primary,
                  ),
              ],
            ),
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
