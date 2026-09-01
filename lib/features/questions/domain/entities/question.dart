import 'package:equatable/equatable.dart';

enum QuestionType { mcq, matchTheFollowing, sortItRight, suddenDeath }

extension QuestionTypeX on QuestionType {
  String get routeValue {
    return switch (this) {
      QuestionType.mcq => 'mcq',
      QuestionType.matchTheFollowing => 'matching',
      QuestionType.sortItRight => 'sortItOut',
      QuestionType.suddenDeath => 'suddenDeath',
    };
  }

  String get label {
    return switch (this) {
      QuestionType.mcq => 'MCQ Quiz',
      QuestionType.matchTheFollowing => 'Match the Following',
      QuestionType.sortItRight => 'Sort It Out',
      QuestionType.suddenDeath => 'Sudden Death',
    };
  }

  String get emptyStateLabel {
    return switch (this) {
      QuestionType.mcq => 'No MCQ questions available for this topic yet.',
      QuestionType.matchTheFollowing =>
        'No Match the Following questions available for this topic yet.',
      QuestionType.sortItRight =>
        'No Sort It Out questions available for this topic yet.',
      QuestionType.suddenDeath =>
        'No Sudden Death questions available for this topic yet.',
    };
  }

  static QuestionType? fromRouteValue(String value) {
    return switch (value) {
      'mcq' => QuestionType.mcq,
      'matching' => QuestionType.matchTheFollowing,
      'sortItOut' => QuestionType.sortItRight,
      'suddenDeath' => QuestionType.suddenDeath,
      _ => null,
    };
  }
}

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
  final String? hint;

  const MatchPair({
    required this.id,
    required this.left,
    required this.right,
    this.hint,
  });

  @override
  List<Object?> get props => [id, left, right, hint];
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
  final String? hint;

  const McqQuestion({
    required super.id,
    required super.topicId,
    required super.prompt,
    required super.points,
    required this.options,
    required this.correctOptionId,
    this.hint,
  });

  @override
  QuestionType get type => QuestionType.mcq;

  @override
  List<Object?> get props => [
    id,
    topicId,
    prompt,
    points,
    options,
    correctOptionId,
    hint,
  ];
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
  List<Object?> get props => [
    id,
    topicId,
    prompt,
    points,
    options,
    correctOptionId,
  ];
}
