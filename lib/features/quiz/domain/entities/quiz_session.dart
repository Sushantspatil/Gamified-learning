import 'package:equatable/equatable.dart';

import '../../../questions/domain/entities/question.dart';
import 'question_answer_record.dart';

/// Represents an in-progress or just-finished attempt, passed to
/// QuizRepository.submitSession so scoring can eventually move server-side
/// without changing this shape.
class QuizSession extends Equatable {
  final String id;
  final String topicId;
  final List<Question> questions;
  final List<QuestionAnswerRecord> answeredRecords;
  final bool endedEarly;

  const QuizSession({
    required this.id,
    required this.topicId,
    required this.questions,
    required this.answeredRecords,
    required this.endedEarly,
  });

  @override
  List<Object?> get props => [id, topicId, questions, answeredRecords, endedEarly];
}
