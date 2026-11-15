import 'entities/match_the_following_models.dart';
import 'entities/sort_it_out_models.dart';
import 'result_answers.dart';

/// Right/wrong dots and review items for Match the Following and Sort It Out,
/// the same shapes `result_answers.dart` gives the multiple-choice modes, so one
/// set of result widgets serves every mode.

// ---------------------------------------------------------------- Match

bool _boardWentWell(MatchBoardReview b) =>
    !b.isTimeout &&
    b.totalPairs > 0 &&
    b.pairsMatched >= b.totalPairs &&
    b.mistakes == 0;

/// One dot per board: green when every pair was matched without a mistake, red
/// otherwise. With no board details it is built from the cleared count.
List<bool> matchBoardFlags(MatchTheFollowingResult result, {int limit = 20}) {
  List<bool> flags;
  if (result.boardsReview.isNotEmpty) {
    flags = [for (final b in result.boardsReview) _boardWentWell(b)];
  } else {
    final cleared = result.clearedBoards.clamp(0, result.totalBoards);
    flags = [
      for (var i = 0; i < cleared; i++) true,
      for (var i = cleared; i < result.totalBoards; i++) false,
    ];
  }
  return flags.length <= limit ? flags : flags.sublist(0, limit);
}

String _plural(int n, String one, String many) => n == 1 ? one : many;

String _seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)}s';

/// How a board went, in one line: "Flawless, 4 of 4 pairs, 6.5s".
String matchBoardDetail(MatchBoardReview b) {
  final pairs = '${b.pairsMatched} of ${b.totalPairs} pairs';
  final time = _seconds(b.timeTakenMs);
  if (b.isTimeout) return "Time's up, $pairs";
  if (_boardWentWell(b)) return 'Flawless, $pairs, $time';
  final mistakes =
      '${b.mistakes} ${_plural(b.mistakes, 'mistake', 'mistakes')}';
  if (b.pairsMatched >= b.totalPairs) {
    return 'Cleared with $mistakes, $time';
  }
  return '$pairs, $mistakes';
}

/// The boards for the review list.
List<ReviewItem> matchReviewItems(MatchTheFollowingResult result) => [
  for (var i = 0; i < result.boardsReview.length; i++)
    ReviewItem(
      number: i + 1,
      prompt: result.boardsReview[i].prompt,
      isCorrect: _boardWentWell(result.boardsReview[i]),
      detail: matchBoardDetail(result.boardsReview[i]),
      explanation: result.boardsReview[i].explanation,
    ),
];

/// The time spent on all boards together.
Duration matchTotalTime(MatchTheFollowingResult result) => Duration(
  milliseconds: result.boardsReview.fold<int>(
    0,
    (sum, b) => sum + b.timeTakenMs,
  ),
);

// ----------------------------------------------------------------- Sort

/// One dot per card: green when it was sorted right in time, red otherwise.
List<bool> sortCardFlags(SortItOutResult result, {int limit = 20}) {
  List<bool> flags;
  if (result.cardsReview.isNotEmpty) {
    flags = [for (final c in result.cardsReview) c.isCorrect && !c.isTimeout];
  } else {
    final correct = result.correctCount.clamp(0, result.totalQuestions);
    flags = [
      for (var i = 0; i < correct; i++) true,
      for (var i = correct; i < result.totalQuestions; i++) false,
    ];
  }
  return flags.length <= limit ? flags : flags.sublist(0, limit);
}

/// The cards for the review list. The server reviews name the chosen side as
/// an id ("a" or "b"); with the [cards] that were played they are shown as the
/// category names the player saw ("Debit", "Credit"), otherwise as "B".
List<ReviewItem> sortReviewItems(
  SortItOutResult result, {
  List<SortItOutCard> cards = const [],
}) {
  String label(String cardId, String optionId) {
    for (final card in cards) {
      if (card.id != cardId) continue;
      for (final option in card.options) {
        if (option.id.toLowerCase() == optionId.toLowerCase()) {
          return option.text;
        }
      }
    }
    return optionId.toUpperCase();
  }

  return [
    for (var i = 0; i < result.cardsReview.length; i++)
      () {
        final c = result.cardsReview[i];
        final right = c.isCorrect && !c.isTimeout;
        return ReviewItem(
          number: i + 1,
          prompt: c.prompt,
          isCorrect: right,
          yourAnswer: c.isTimeout
              ? "Time's up"
              : (c.selectedOption.isEmpty
                    ? null
                    : label(c.question, c.selectedOption)),
          correctAnswer: label(c.question, c.correctOption),
          explanation: c.explanation,
        );
      }(),
  ];
}

/// The time spent on all cards together.
Duration sortTotalTime(SortItOutResult result) => Duration(
  milliseconds: result.cardsReview.fold<int>(
    0,
    (sum, c) => sum + c.timeTakenMs,
  ),
);
