import 'package:flutter/foundation.dart';
import '../../../../core/network/dtos/quiz_dtos.dart';

/// Represents a single selectable item on the left or right side of a Match board.
@immutable
class MatchPairItem {
  final String id;
  final String text;

  const MatchPairItem({
    required this.id,
    required this.text,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchPairItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text;

  @override
  int get hashCode => id.hashCode ^ text.hashCode;
}

/// Represents a single multi-pair matching puzzle board delivered upfront.
@immutable
class MatchBoard {
  final String questionCode;
  final String prompt;
  final int timeLimitSec;
  final List<MatchPairItem> leftItems;
  final List<MatchPairItem> rightItems;
  final Map<String, String> solutionMap; // left_id -> right_id
  final String? hint;
  final String? explanation;

  const MatchBoard({
    required this.questionCode,
    required this.prompt,
    this.timeLimitSec = 25,
    required this.leftItems,
    required this.rightItems,
    this.solutionMap = const {},
    this.hint,
    this.explanation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchBoard &&
          runtimeType == other.runtimeType &&
          questionCode == other.questionCode;

  @override
  int get hashCode => questionCode.hashCode;
}

/// Represents the completed user answers and metrics for a single Match board.
@immutable
class MatchBoardSubmission {
  final String questionCode;
  final Map<String, String> matches; // confirmed correct left_id -> right_id
  final int mistakes;
  final int timeTakenMs;
  final bool isTimeout;

  const MatchBoardSubmission({
    required this.questionCode,
    required this.matches,
    this.mistakes = 0,
    required this.timeTakenMs,
    this.isTimeout = false,
  });

  MatchBoardAnswerSubmissionDto toDto() => MatchBoardAnswerSubmissionDto(
        questionCode: questionCode,
        matches: matches,
        mistakes: mistakes,
        timeTakenMs: timeTakenMs,
        isTimeout: isTimeout,
      );
}

/// Audited breakdown of a single Match board returned authoritatively from the backend.
@immutable
class MatchBoardReview {
  final String questionCode;
  final String prompt;
  final int pairsMatched;
  final int totalPairs;
  final int mistakes;
  final int timeTakenMs;
  final bool isFlawless;
  final bool isTimeout;
  final int basePoints;
  final int flawlessBonus;
  final int speedBonus;
  final int mistakePenalty;
  final int totalBoardScore;
  final String? explanation;

  const MatchBoardReview({
    required this.questionCode,
    required this.prompt,
    required this.pairsMatched,
    required this.totalPairs,
    required this.mistakes,
    required this.timeTakenMs,
    required this.isFlawless,
    required this.isTimeout,
    required this.basePoints,
    required this.flawlessBonus,
    required this.speedBonus,
    required this.mistakePenalty,
    required this.totalBoardScore,
    this.explanation,
  });

  factory MatchBoardReview.fromDto(MatchBoardReviewDto dto) =>
      MatchBoardReview(
        questionCode: dto.questionCode,
        prompt: dto.prompt,
        pairsMatched: dto.pairsMatched,
        totalPairs: dto.totalPairs,
        mistakes: dto.mistakes,
        timeTakenMs: dto.timeTakenMs,
        isFlawless: dto.isFlawless,
        isTimeout: dto.isTimeout,
        basePoints: dto.basePoints,
        flawlessBonus: dto.flawlessBonus,
        speedBonus: dto.speedBonus,
        mistakePenalty: dto.mistakePenalty,
        totalBoardScore: dto.totalBoardScore,
        explanation: dto.explanation,
      );
}

/// Rich authoritatively reconciled end-of-game summary for Match the Following.
@immutable
class MatchTheFollowingResult {
  final String session;
  final int totalBoards;
  final int clearedBoards;
  final int totalPairsMatched;
  final int totalPairsCount;
  final int totalMistakes;
  final double accuracyPercentage;
  final int finalScore;
  final int coinsAwarded;
  final int xpAwarded;
  final int gemsAwarded;
  final Map<String, int> scoreBreakdown;
  final Map<String, int> coinBreakdown;
  final Map<String, int> xpBreakdown;
  final LevelUpRewardDto? levelUpReward;
  final LevelProgressDto? level;
  final StreakSummaryDto? streak;
  final List<MatchBoardReview> boardsReview;

  const MatchTheFollowingResult({
    required this.session,
    required this.totalBoards,
    required this.clearedBoards,
    required this.totalPairsMatched,
    required this.totalPairsCount,
    required this.totalMistakes,
    required this.accuracyPercentage,
    required this.finalScore,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.gemsAwarded,
    this.scoreBreakdown = const {},
    this.coinBreakdown = const {},
    this.xpBreakdown = const {},
    this.levelUpReward,
    this.level,
    this.streak,
    this.boardsReview = const [],
  });

  factory MatchTheFollowingResult.fromDto(
          CompleteMatchTheFollowingResponseDto dto) =>
      MatchTheFollowingResult(
        session: dto.session,
        totalBoards: dto.totalBoards,
        clearedBoards: dto.clearedBoards,
        totalPairsMatched: dto.totalPairsMatched,
        totalPairsCount: dto.totalPairsCount,
        totalMistakes: dto.totalMistakes,
        accuracyPercentage: dto.accuracyPercentage,
        finalScore: dto.finalScore,
        coinsAwarded: dto.coinsAwarded,
        xpAwarded: dto.xpAwarded,
        gemsAwarded: dto.gemsAwarded,
        scoreBreakdown: dto.scoreBreakdown,
        coinBreakdown: dto.coinBreakdown,
        xpBreakdown: dto.xpBreakdown,
        levelUpReward: dto.levelUpReward,
        level: dto.level,
        streak: dto.streak,
        boardsReview: dto.boardsReview
            .map((b) => MatchBoardReview.fromDto(b))
            .toList(growable: false),
      );
}
