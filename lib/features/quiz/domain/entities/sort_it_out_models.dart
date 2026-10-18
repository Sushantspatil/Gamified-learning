import 'package:equatable/equatable.dart';

import '../../../../core/network/dtos/quiz_dtos.dart';
import '../../../questions/domain/entities/question.dart';

/// Represents a single swipeable rapid-fire classification card.
class SortItOutCard extends Equatable {
  final String id;
  final String prompt;
  final int points;
  final String? hint;
  final int? timeLimitSec;
  final List<QuestionOption> options;
  final String? correctOption;
  final String? pairType;
  final String? explanation;

  const SortItOutCard({
    required this.id,
    required this.prompt,
    required this.points,
    this.hint,
    this.timeLimitSec,
    required this.options,
    this.correctOption,
    this.pairType,
    this.explanation,
  });

  QuestionOption? get optionA => options.isNotEmpty ? options[0] : null;
  QuestionOption? get optionB => options.length > 1 ? options[1] : null;

  String get labelA => optionA?.text ?? 'Option A';
  String get labelB => optionB?.text ?? 'Option B';

  String categoryLabel(SortSide side) =>
      side == SortSide.left ? labelA : labelB;

  @override
  List<Object?> get props => [
        id,
        prompt,
        points,
        hint,
        timeLimitSec,
        options,
        correctOption,
        pairType,
        explanation,
      ];
}

/// Represents a recorded answer for a single Sort It Out card.
class SortItOutAnswer extends Equatable {
  final String question;
  final String option;
  final int timeTakenMs;
  final bool isTimeout;

  const SortItOutAnswer({
    required this.question,
    required this.option,
    required this.timeTakenMs,
    this.isTimeout = false,
  });

  SortItOutAnswerSubmissionDto toDto() => SortItOutAnswerSubmissionDto(
        question: question,
        option: option,
        timeTakenMs: timeTakenMs,
        isTimeout: isTimeout,
      );

  @override
  List<Object?> get props => [question, option, timeTakenMs, isTimeout];
}

/// Comprehensive audit review for a single Sort It Out card returned by the server.
class SortItOutCardReview extends Equatable {
  final String question;
  final String prompt;
  final String selectedOption;
  final String correctOption;
  final bool isCorrect;
  final bool isTimeout;
  final int timeTakenMs;
  final int basePoints;
  final int speedBonus;
  final int comboBonus;
  final int pointsEarned;
  final String? explanation;

  const SortItOutCardReview({
    required this.question,
    required this.prompt,
    required this.selectedOption,
    required this.correctOption,
    required this.isCorrect,
    required this.isTimeout,
    required this.timeTakenMs,
    required this.basePoints,
    required this.speedBonus,
    required this.comboBonus,
    required this.pointsEarned,
    this.explanation,
  });

  factory SortItOutCardReview.fromDto(SortItOutCardReviewDto dto) =>
      SortItOutCardReview(
        question: dto.question,
        prompt: dto.prompt,
        selectedOption: dto.selectedOption,
        correctOption: dto.correctOption,
        isCorrect: dto.isCorrect,
        isTimeout: dto.isTimeout,
        timeTakenMs: dto.timeTakenMs,
        basePoints: dto.basePoints,
        speedBonus: dto.speedBonus,
        comboBonus: dto.comboBonus,
        pointsEarned: dto.pointsEarned,
        explanation: dto.explanation,
      );

  @override
  List<Object?> get props => [
        question,
        prompt,
        selectedOption,
        correctOption,
        isCorrect,
        isTimeout,
        timeTakenMs,
        basePoints,
        speedBonus,
        comboBonus,
        pointsEarned,
        explanation,
      ];
}

/// Authoritative end-of-deck summary returned by the backend for Sort It Out.
class SortItOutResult extends Equatable {
  final String session;
  final String pairType;
  final int totalQuestions;
  final int correctCount;
  final int timeoutCount;
  final int bestStreak;
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
  final List<SortItOutCardReview> cardsReview;

  const SortItOutResult({
    required this.session,
    required this.pairType,
    required this.totalQuestions,
    required this.correctCount,
    required this.timeoutCount,
    required this.bestStreak,
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
    this.cardsReview = const [],
  });

  factory SortItOutResult.fromDto(CompleteSortItOutResponseDto dto) =>
      SortItOutResult(
        session: dto.session,
        pairType: dto.pairType,
        totalQuestions: dto.totalQuestions,
        correctCount: dto.correctCount,
        timeoutCount: dto.timeoutCount,
        bestStreak: dto.bestStreak,
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
        cardsReview:
            dto.cardsReview.map(SortItOutCardReview.fromDto).toList(),
      );

  int get basePoints => scoreBreakdown['base_points'] ?? (correctCount * 10);
  int get speedBonus => scoreBreakdown['speed_bonus'] ?? 0;
  int get comboBonus => scoreBreakdown['combo_bonus'] ?? 0;
  bool get didLevelUp => level?.didLevelUp ?? false;

  @override
  List<Object?> get props => [
        session,
        pairType,
        totalQuestions,
        correctCount,
        timeoutCount,
        bestStreak,
        accuracyPercentage,
        finalScore,
        coinsAwarded,
        xpAwarded,
        gemsAwarded,
        scoreBreakdown,
        coinBreakdown,
        xpBreakdown,
        levelUpReward,
        level,
        streak,
        cardsReview,
      ];
}
