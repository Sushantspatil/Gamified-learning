import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/entities/sort_it_out_models.dart';
import '../../domain/mode_result_answers.dart';
import '../../domain/result_flow.dart';
import '../../domain/result_outcome.dart';
import 'quiz_celebration_overlay.dart';
import 'result/answer_review_sheet.dart';
import 'result/answer_strip.dart';
import 'result/game_result_flow.dart';
import 'result/personal_best_badge.dart';
import 'result/result_breakdown.dart';
import 'result/result_share.dart';
import 'result/result_summary.dart';

/// The result of a Sort It Out game, in the same shape as every other mode: a
/// summary screen (score, a dot for every card, XP / accuracy / time), a
/// progress screen only when something changed, and the review of the cards
/// (the missed ones first) and the score breakdown one tap away.
class SortItOutResultView extends StatelessWidget {
  final SortItOutResult result;
  final VoidCallback onDone;
  final VoidCallback? onPlayAgain;

  /// The cards that were played. With them the review names the categories the
  /// player saw ("Debit" / "Credit") instead of "A" / "B".
  final List<SortItOutCard> cards;

  const SortItOutResultView({
    super.key,
    required this.result,
    required this.onDone,
    this.onPlayAgain,
    this.cards = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final accuracy = (result.accuracyPercentage / 100)
        .clamp(0.0, 1.0)
        .toDouble();

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

    final outcome = outcomeFor(
      endedEarly: false,
      correct: result.correctCount,
      total: result.totalQuestions,
    );
    final accent = resultAccent(context, outcome: outcome, accuracy: accuracy);
    final reviewItems = sortReviewItems(result, cards: cards);
    final time = sortTotalTime(result);
    final level = result.level;

    Widget summaryFor(String? playerName) => ResultSummary(
      outcome: outcome,
      accent: accent,
      playerName: playerName,
      eyebrow:
          '${result.correctCount} OF ${result.totalQuestions} SORTED RIGHT',
      points: result.finalScore,
      coins: result.coinsAwarded,
      gems: result.gemsAwarded,
      tiles: [
        ResultTileData.number(
          label: 'XP',
          icon: Icons.bolt_rounded,
          color: AppColors.xpPurple,
          number: result.xpAwarded,
          prefix: '+',
        ),
        ResultTileData.number(
          label: 'ACCURACY',
          icon: Icons.track_changes_rounded,
          color: colors.success,
          number: result.accuracyPercentage.round(),
          suffix: '%',
        ),
        if (time > Duration.zero)
          ResultTileData.text(
            label: 'TIME',
            icon: Icons.timer_rounded,
            color: colors.info,
            text: formatResultTime(time),
          )
        else
          ResultTileData.number(
            label: 'BEST STREAK',
            icon: Icons.local_fire_department_rounded,
            color: AppColors.streakFire,
            number: result.bestStreak,
          ),
      ],
      bestBadge: PersonalBestBadge(
        modeKey: 'sort_it_out',
        score: result.finalScore,
      ),
      answers: AnswerStrip(
        flags: sortCardFlags(result),
        reviewLabel: 'Review your cards',
        onTap: reviewItems.isEmpty
            ? null
            : () => showAnswerReview(
                context,
                reviewItems,
                title: 'Your cards',
                perfectText: 'Every card was sorted right. Perfect!',
              ),
      ),
      mascot: resultMascotFor(
        context,
        unsuccessful: isUnsuccessful,
        accuracy: accuracy,
      ),
    );

    return GameResultFlow(
      sessionKey: 'sort-${result.session}',
      celebrationType: celebrationType,
      summary: WithPlayerName(builder: summaryFor),
      levelProgress: level == null
          ? null
          : QuizLevelProgress(
              currentLevel: level.current,
              experience: level.experience,
              nextLevelExperience: level.nextLevelExp,
            ),
      earnedXp: result.xpAwarded,
      leveledUp: result.didLevelUp || result.levelUpReward != null,
      share: ShareResult(
        mode: ShareMode.sortItOut,
        points: result.finalScore,
        correct: result.correctCount,
        total: result.totalQuestions,
        accuracy: accuracy,
        time: time > Duration.zero ? time : null,
      ),
      onDone: onDone,
      onPlayAgain: onPlayAgain,
      onDetails: (context) {
        final colors = context.themeColors;
        showResultDetailsSheet(context, [
          ResultBreakdownCard(
            lines: [
              BreakdownLine(
                label: 'Base Points',
                value: '+${result.basePoints}',
                color: colors.textSecondary,
              ),
              BreakdownLine(
                label: 'Speed Bonus',
                value: '+${result.speedBonus}',
                color: colors.secondary,
              ),
              BreakdownLine(
                label: 'Combo Bonus',
                value: '+${result.comboBonus}',
                color: AppColors.streakFire,
              ),
            ],
            finalValue: '${result.finalScore}',
          ),
          if (result.bestStreak > 0 || result.timeoutCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              [
                if (result.bestStreak > 0)
                  'Best streak: ${result.bestStreak} in a row',
                if (result.timeoutCount > 0)
                  '${result.timeoutCount} ran out of time',
              ].join('  ·  '),
              textAlign: TextAlign.center,
              style: context.appTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ]);
      },
    );
  }
}
