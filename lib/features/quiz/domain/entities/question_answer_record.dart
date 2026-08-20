import 'package:equatable/equatable.dart';

import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/answer_evaluation.dart';
import '../../../questions/domain/entities/question.dart';

class QuestionAnswerRecord extends Equatable {
  final Question question;
  final Answer answer;
  final AnswerEvaluation evaluation;

  const QuestionAnswerRecord({
    required this.question,
    required this.answer,
    required this.evaluation,
  });

  @override
  List<Object?> get props => [question, answer, evaluation];
}
