import 'package:equatable/equatable.dart';

class AnswerEvaluation extends Equatable {
  final bool isCorrect;
  final int pointsEarned;

  const AnswerEvaluation({required this.isCorrect, required this.pointsEarned});

  @override
  List<Object?> get props => [isCorrect, pointsEarned];
}
