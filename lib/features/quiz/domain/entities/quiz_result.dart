import 'package:equatable/equatable.dart';

import '../../../questions/domain/entities/question.dart';
import 'question_answer_record.dart';

class Score extends Equatable {
  final int earnedPoints;
  final int maxPoints;
  final int correctCount;
  final int totalCount;

  const Score({
    required this.earnedPoints,
    required this.maxPoints,
    required this.correctCount,
    required this.totalCount,
  });

  double get percentage => maxPoints == 0 ? 0 : earnedPoints / maxPoints;
  int get wrongCount => totalCount - correctCount;

  @override
  List<Object?> get props => [
    earnedPoints,
    maxPoints,
    correctCount,
    totalCount,
  ];
}

class RewardBreakdownItem extends Equatable {
  final String key;
  final int amount;

  const RewardBreakdownItem({required this.key, required this.amount});

  @override
  List<Object?> get props => [key, amount];
}

class QuizRewardBreakdown extends Equatable {
  final List<RewardBreakdownItem> score;
  final List<RewardBreakdownItem> xp;
  final List<RewardBreakdownItem> coins;
  final List<RewardBreakdownItem> levelUp;

  const QuizRewardBreakdown({
    this.score = const [],
    this.xp = const [],
    this.coins = const [],
    this.levelUp = const [],
  });

  bool get hasScore => score.any((item) => item.amount != 0);
  bool get hasXp => xp.any((item) => item.amount != 0);
  bool get hasCoins => coins.any((item) => item.amount != 0);
  bool get hasLevelUp => levelUp.any((item) => item.amount != 0);

  @override
  List<Object?> get props => [score, xp, coins, levelUp];
}

class QuizLevelProgress extends Equatable {
  final int currentLevel;
  final int experience;
  final int nextLevelExperience;

  const QuizLevelProgress({
    required this.currentLevel,
    required this.experience,
    required this.nextLevelExperience,
  });

  double get progress => nextLevelExperience <= 0
      ? 0
      : (experience / nextLevelExperience).clamp(0, 1).toDouble();

  @override
  List<Object?> get props => [currentLevel, experience, nextLevelExperience];
}

/// Returned by QuizRepository.submitSession. Today the mock datasource
/// computes this from the client-reported records; once a backend exists
/// this must be recomputed/verified server-side rather than trusted as-is
/// (see Step 10 economy/anti-tampering requirements).
class QuizResult extends Equatable {
  final String sessionId;
  final String? userId;
  final String? subjectId;
  final String? chapterId;
  final String topicId;
  final QuestionType quizType;
  final Score score;
  final List<QuestionAnswerRecord> records;
  final bool endedEarly;
  final int streakCount;
  final int xpAwarded;
  final int coinsAwarded;
  final int gemsAwarded;
  final bool didLevelUp;
  final QuizRewardBreakdown rewardBreakdown;
  final QuizLevelProgress? levelProgress;
  final Duration timeTaken;
  final DateTime createdAt;

  const QuizResult({
    required this.sessionId,
    this.userId,
    this.subjectId,
    this.chapterId,
    required this.topicId,
    required this.quizType,
    required this.score,
    required this.records,
    required this.endedEarly,
    required this.streakCount,
    this.xpAwarded = 0,
    this.coinsAwarded = 0,
    this.gemsAwarded = 0,
    this.didLevelUp = false,
    this.rewardBreakdown = const QuizRewardBreakdown(),
    this.levelProgress,
    required this.timeTaken,
    required this.createdAt,
  });

  double get accuracy =>
      score.totalCount == 0 ? 0 : score.correctCount / score.totalCount;
  int get wrongCount => score.wrongCount;

  @override
  List<Object?> get props => [
    sessionId,
    userId,
    subjectId,
    chapterId,
    topicId,
    quizType,
    score,
    records,
    endedEarly,
    streakCount,
    xpAwarded,
    coinsAwarded,
    gemsAwarded,
    didLevelUp,
    rewardBreakdown,
    levelProgress,
    timeTaken,
    createdAt,
  ];
}
