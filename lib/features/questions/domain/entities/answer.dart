import 'package:equatable/equatable.dart';
import 'question.dart';

sealed class Answer extends Equatable {
  final String questionId;

  const Answer(this.questionId);
}

class McqAnswer extends Answer {
  final String selectedOptionId;

  const McqAnswer({required String questionId, required this.selectedOptionId})
    : super(questionId);

  @override
  List<Object?> get props => [questionId, selectedOptionId];
}

/// Maps each MatchPair.id (the left item) to the pair id the learner
/// matched it to. Correct when key == value for every pair.
class MatchTheFollowingAnswer extends Answer {
  final Map<String, String> matchedPairIds;

  const MatchTheFollowingAnswer({
    required String questionId,
    required this.matchedPairIds,
  }) : super(questionId);

  @override
  List<Object?> get props => [questionId, matchedPairIds];
}

class SortAnswer extends Answer {
  final List<String> orderedItems;
  final List<SortSide> selectedSides;

  const SortAnswer({
    required String questionId,
    required this.orderedItems,
    this.selectedSides = const [],
  }) : super(questionId);

  @override
  List<Object?> get props => [questionId, orderedItems, selectedSides];
}

class SuddenDeathAnswer extends Answer {
  final String selectedOptionId;

  const SuddenDeathAnswer({
    required String questionId,
    required this.selectedOptionId,
  }) : super(questionId);

  @override
  List<Object?> get props => [questionId, selectedOptionId];
}
