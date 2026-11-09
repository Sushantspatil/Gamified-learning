import '../../questions/domain/entities/answer.dart';
import '../../questions/domain/entities/question.dart';
import 'entities/quiz_result.dart';

/// One question as shown in the "Review answers" list.
class ReviewItem {
  /// 1-based position in the game.
  final int number;
  final String prompt;
  final bool isCorrect;

  /// The option the player chose, or null if they skipped or it is unknown.
  final String? yourAnswer;

  /// The right option.
  final String correctAnswer;

  const ReviewItem({
    required this.number,
    required this.prompt,
    required this.isCorrect,
    required this.yourAnswer,
    required this.correctAnswer,
  });
}

/// Right (true) or wrong (false) for each question, in the order they were
/// asked. This is the row of dots on the result screen.
///
/// With the answers on hand it is exact. Without them (a result that only has
/// totals, like Sudden Death) it is built from the counts: the right ones first,
/// then the wrong ones. Either way it is capped at [limit] dots.
List<bool> answerFlags(QuizResult result, {int limit = 20}) {
  List<bool> flags;
  if (result.records.isNotEmpty) {
    flags = [for (final r in result.records) r.evaluation.isCorrect];
  } else {
    final correct = result.score.correctCount;
    final wrong = result.endedEarly
        ? (result.score.totalCount > correct ? 1 : 0)
        : result.score.totalCount - correct;
    flags = [
      for (var i = 0; i < correct; i++) true,
      for (var i = 0; i < wrong; i++) false,
    ];
  }
  return flags.length <= limit ? flags : flags.sublist(0, limit);
}

/// The questions with the player's answer and the right one, for the review
/// list. Only multiple-choice answers can be reviewed; anything else (or a
/// result with no answers on hand) gives an empty list, so no review is offered.
List<ReviewItem> reviewItemsFor(QuizResult result) {
  final items = <ReviewItem>[];
  for (var i = 0; i < result.records.length; i++) {
    final record = result.records[i];
    final question = record.question;
    if (question is! McqQuestion) continue;

    String? textOf(String id) {
      for (final option in question.options) {
        if (option.id == id) return option.text;
      }
      return null;
    }

    final chosen = switch (record.answer) {
      McqAnswer(:final selectedOptionId) => selectedOptionId,
      SuddenDeathAnswer(:final selectedOptionId) => selectedOptionId,
      _ => null,
    };
    items.add(
      ReviewItem(
        number: i + 1,
        prompt: question.prompt,
        isCorrect: record.evaluation.isCorrect,
        yourAnswer: chosen == null ? null : textOf(chosen),
        correctAnswer: textOf(question.correctOptionId) ?? '',
      ),
    );
  }
  return items;
}
