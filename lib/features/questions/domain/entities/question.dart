import 'package:equatable/equatable.dart';

enum QuestionType { mcq, matchTheFollowing, sortItRight, suddenDeath }

class QuestionOption extends Equatable {
  final String id;
  final String text;

  const QuestionOption({required this.id, required this.text});

  @override
  List<Object?> get props => [id, text];
}

class MatchPair extends Equatable {
  final String id;
  final String left;
  final String right;

  const MatchPair({required this.id, required this.left, required this.right});

  @override
  List<Object?> get props => [id, left, right];
}

/// Sealed so every consumer (scoring, UI dispatch) gets exhaustiveness
/// checking from the compiler — adding a new question type forces every
/// switch site to be updated rather than silently falling through.
sealed class Question extends Equatable {
  final String id;
  final String topicId;
  final String prompt;
  final int points;

  const Question({
    required this.id,
    required this.topicId,
    required this.prompt,
    required this.points,
  });

  QuestionType get type;
}

class McqQuestion extends Question {
  final List<QuestionOption> options;
  final String correctOptionId;

  const McqQuestion({
    required super.id,
    required super.topicId,
    required super.prompt,
    required super.points,
    required this.options,
    required this.correctOptionId,
  });

  @override
  QuestionType get type => QuestionType.mcq;

  @override
  List<Object?> get props => [id, topicId, prompt, points, options, correctOptionId];
}

class MatchTheFollowingQuestion extends Question {
  final List<MatchPair> pairs;

  const MatchTheFollowingQuestion({
    required super.id,
    required super.topicId,
    required super.prompt,
    required super.points,
    required this.pairs,
  });

  @override
  QuestionType get type => QuestionType.matchTheFollowing;

  @override
  List<Object?> get props => [id, topicId, prompt, points, pairs];
}

class SortItRightQuestion extends Question {
  final List<String> itemsInOrder;

  const SortItRightQuestion({
    required super.id,
    required super.topicId,
    required super.prompt,
    required super.points,
    required this.itemsInOrder,
  });

  @override
  QuestionType get type => QuestionType.sortItRight;

  @override
  List<Object?> get props => [id, topicId, prompt, points, itemsInOrder];
}

/// One wrong answer ends the whole quiz session immediately — enforced by
/// QuizController, not here; this entity just carries the same MCQ-shaped
/// content.
class SuddenDeathQuestion extends Question {
  final List<QuestionOption> options;
  final String correctOptionId;

  const SuddenDeathQuestion({
    required super.id,
    required super.topicId,
    required super.prompt,
    required super.points,
    required this.options,
    required this.correctOptionId,
  });

  @override
  QuestionType get type => QuestionType.suddenDeath;

  @override
  List<Object?> get props => [id, topicId, prompt, points, options, correctOptionId];
}
