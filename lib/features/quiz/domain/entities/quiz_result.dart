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
    timeTaken,
    createdAt,
  ];
}
