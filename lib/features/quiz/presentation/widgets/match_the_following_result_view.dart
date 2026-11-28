import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../domain/entities/match_the_following_models.dart';
import '../../domain/entities/quiz_result.dart';
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

/// The result of a Match the Following game, in the same shape as every other
/// mode: a summary screen (score, a dot for every board, XP / accuracy / time),
/// a progress screen only when something changed, and the board-by-board review
/// and the score breakdown one tap away.
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
    final accuracy = (result.accuracyPercentage / 100)
        .clamp(0.0, 1.0)
        .toDouble();

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

    final outcome = outcomeFor(
      endedEarly: false,
      correct: result.totalPairsMatched,
      total: result.totalPairsCount,
    );
    final accent = resultAccent(context, outcome: outcome, accuracy: accuracy);
    final reviewItems = matchReviewItems(result);
    final time = matchTotalTime(result);
    final leveledUp =
        result.level?.didLevelUp == true || result.levelUpReward != null;
    final level = result.level;

    Widget summaryFor(String? playerName) => ResultSummary(
      outcome: outcome,
      accent: accent,
      playerName: playerName,
      eyebrow:
          '${result.clearedBoards} OF ${result.totalBoards} BOARDS CLEARED',
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
          ResultTileData.text(
            label: 'PAIRS',
            icon: Icons.link_rounded,
            color: colors.info,
            text: '${result.totalPairsMatched}/${result.totalPairsCount}',
          ),
      ],
      bestBadge: PersonalBestBadge(
        modeKey: 'match_the_following',
        score: result.finalScore,
      ),
      answers: AnswerStrip(
        flags: matchBoardFlags(result),
        reviewLabel: 'Review your boards',
        onTap: reviewItems.isEmpty
            ? null
            : () => showAnswerReview(
                context,
                reviewItems,
                title: 'Your boards',
                wrongLabel: 'Needs work',
                summary: (wrong, right) => '$wrong to improve, $right flawless',
                perfectText: 'Every board was flawless. Perfect!',
              ),
      ),
      mascot: resultMascotFor(
        context,
        unsuccessful: isUnsuccessful,
        accuracy: accuracy,
      ),
    );

    return GameResultFlow(
      sessionKey: 'match-${result.session}',
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
      leveledUp: leveledUp,
      share: ShareResult(
        mode: ShareMode.match,
        points: result.finalScore,
        correct: result.totalPairsMatched,
        total: result.totalPairsCount,
        accuracy: accuracy,
        time: time > Duration.zero ? time : null,
      ),
      onDone: onDone,
      onPlayAgain: onPlayAgain,
      onDetails: (context) {
        final colors = context.themeColors;
        final breakdown = result.scoreBreakdown;
        final penalty = breakdown['mistake_penalty'] ?? 0;
        showResultDetailsSheet(context, [
          ResultBreakdownCard(
            lines: [
              BreakdownLine(
                label: 'Base Points',
                value: '+${breakdown['base_points'] ?? 0}',
                color: colors.textSecondary,
              ),
              BreakdownLine(
                label: 'Flawless Bonus',
                value: '+${breakdown['flawless_bonus'] ?? 0}',
                color: colors.success,
              ),
              BreakdownLine(
                label: 'Speed Bonus',
                value: '+${breakdown['speed_bonus'] ?? 0}',
                color: colors.secondary,
              ),
              if (penalty != 0)
                BreakdownLine(
                  label: 'Mistake Penalty',
                  value: '-${penalty.abs()}',
                  color: colors.error,
                ),
            ],
            finalValue: '${result.finalScore}',
          ),
        ]);
      },
    );
  }
}
