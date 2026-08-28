import 'package:equatable/equatable.dart';

import '../../../questions/domain/entities/question.dart';
import 'question_answer_record.dart';

/// Represents an in-progress or just-finished attempt, passed to
/// QuizRepository.submitSession so scoring can eventually move server-side
/// without changing this shape.
class QuizSession extends Equatable {
  final String id;
  final String? userId;
  final String? subjectId;
  final String? chapterId;
  final String topicId;
  final QuestionType quizType;
  final List<Question> questions;
  final List<QuestionAnswerRecord> answeredRecords;
  final bool endedEarly;
  final DateTime startedAt;
  final DateTime completedAt;

  const QuizSession({
    required this.id,
    this.userId,
    this.subjectId,
    this.chapterId,
    required this.topicId,
    required this.quizType,
    required this.questions,
    required this.answeredRecords,
    required this.endedEarly,
    required this.startedAt,
    required this.completedAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    subjectId,
    chapterId,
    topicId,
    quizType,
    questions,
    answeredRecords,
    endedEarly,
    startedAt,
    completedAt,
  ];
}
