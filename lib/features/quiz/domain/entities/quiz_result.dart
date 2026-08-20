import 'package:equatable/equatable.dart';

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

  @override
  List<Object?> get props => [earnedPoints, maxPoints, correctCount, totalCount];
}

/// Returned by QuizRepository.submitSession. Today the mock datasource
/// computes this from the client-reported records; once a backend exists
/// this must be recomputed/verified server-side rather than trusted as-is
/// (see Step 10 economy/anti-tampering requirements).
class QuizResult extends Equatable {
  final String sessionId;
  final String topicId;
  final Score score;
  final List<QuestionAnswerRecord> records;
  final bool endedEarly;

  const QuizResult({
    required this.sessionId,
    required this.topicId,
    required this.score,
    required this.records,
    required this.endedEarly,
  });

  @override
  List<Object?> get props => [sessionId, topicId, score, records, endedEarly];
}
