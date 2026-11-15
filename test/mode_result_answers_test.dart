import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/domain/entities/match_the_following_models.dart';
import 'package:skillverse_app/features/quiz/domain/entities/sort_it_out_models.dart';
import 'package:skillverse_app/features/quiz/domain/mode_result_answers.dart';

MatchBoardReview _board({
  required int matched,
  int mistakes = 0,
  bool timeout = false,
  int ms = 5000,
  String prompt = 'Board',
}) => MatchBoardReview(
  questionCode: 'b',
  prompt: prompt,
  pairsMatched: matched,
  totalPairs: 4,
  mistakes: mistakes,
  timeTakenMs: ms,
  isFlawless: matched == 4 && mistakes == 0 && !timeout,
  isTimeout: timeout,
  basePoints: 0,
  flawlessBonus: 0,
  speedBonus: 0,
  mistakePenalty: 0,
  totalBoardScore: 0,
);

MatchTheFollowingResult _match(
  List<MatchBoardReview> boards, {
  int totalBoards = 3,
  int cleared = 2,
}) => MatchTheFollowingResult(
  session: 's',
  totalBoards: totalBoards,
  clearedBoards: cleared,
  totalPairsMatched: 0,
  totalPairsCount: 0,
  totalMistakes: 0,
  accuracyPercentage: 0,
  finalScore: 0,
  coinsAwarded: 0,
  xpAwarded: 0,
  gemsAwarded: 0,
  boardsReview: boards,
);

SortItOutCardReview _card(
  String id, {
  String chose = 'b',
  String correct = 'b',
  bool timeout = false,
  int ms = 1000,
}) => SortItOutCardReview(
  question: id,
  prompt: 'Prompt $id',
  selectedOption: timeout ? 'timeout' : chose,
  correctOption: correct,
  isCorrect: chose == correct && !timeout,
  isTimeout: timeout,
  timeTakenMs: ms,
  basePoints: 0,
  speedBonus: 0,
  comboBonus: 0,
  pointsEarned: 0,
);

SortItOutResult _sort(
  List<SortItOutCardReview> cards, {
  int total = 3,
  int correct = 1,
}) => SortItOutResult(
  session: 's',
  pairType: 'p',
  totalQuestions: total,
  correctCount: correct,
  timeoutCount: 0,
  bestStreak: 0,
  accuracyPercentage: 0,
  finalScore: 0,
  coinsAwarded: 0,
  xpAwarded: 0,
  gemsAwarded: 0,
  cardsReview: cards,
);

void main() {
  group('Match', () {
    test('a board is green only when flawless', () {
      final flags = matchBoardFlags(
        _match([
          _board(matched: 4),
          _board(matched: 4, mistakes: 1),
          _board(matched: 2),
          _board(matched: 4, timeout: true),
        ]),
      );
      expect(flags, [true, false, false, false]);
    });

    test('without board details the dots come from the cleared count', () {
      expect(matchBoardFlags(_match(const [])), [true, true, false]);
    });

    test('the dots are capped', () {
      final flags = matchBoardFlags(
        _match([for (var i = 0; i < 30; i++) _board(matched: 4)]),
        limit: 20,
      );
      expect(flags, hasLength(20));
    });

    test('says how each board went', () {
      expect(
        matchBoardDetail(_board(matched: 4, ms: 6500)),
        'Flawless, 4 of 4 pairs, 6.5s',
      );
      expect(
        matchBoardDetail(_board(matched: 4, mistakes: 1, ms: 12000)),
        'Cleared with 1 mistake, 12.0s',
      );
      expect(
        matchBoardDetail(_board(matched: 4, mistakes: 3, ms: 12000)),
        'Cleared with 3 mistakes, 12.0s',
      );
      expect(
        matchBoardDetail(_board(matched: 2, mistakes: 2)),
        '2 of 4 pairs, 2 mistakes',
      );
      expect(
        matchBoardDetail(_board(matched: 1, timeout: true)),
        "Time's up, 1 of 4 pairs",
      );
    });

    test('review items are numbered, with their explanation', () {
      final items = matchReviewItems(
        _match([
          _board(matched: 4, prompt: 'First'),
          _board(matched: 2, prompt: 'Second'),
        ]),
      );
      expect(items.map((i) => i.number), [1, 2]);
      expect(items.map((i) => i.isCorrect), [true, false]);
      expect(items.first.prompt, 'First');
      expect(items.first.correctAnswer, isEmpty);
      expect(items.first.detail, isNotNull);
    });

    test('total time adds up the boards', () {
      expect(
        matchTotalTime(
          _match([_board(matched: 4, ms: 1500), _board(matched: 4, ms: 2500)]),
        ),
        const Duration(seconds: 4),
      );
      expect(matchTotalTime(_match(const [])), Duration.zero);
    });
  });

  group('Sort', () {
    test('a card is green only when right and in time', () {
      final flags = sortCardFlags(
        _sort([
          _card('q1'),
          _card('q2', chose: 'a'),
          _card('q3', timeout: true),
        ]),
      );
      expect(flags, [true, false, false]);
    });

    test('without card details the dots come from the counts', () {
      expect(sortCardFlags(_sort(const [], total: 3, correct: 2)), [
        true,
        true,
        false,
      ]);
    });

    test('names the sides with the played cards', () {
      const options = [
        QuestionOption(id: 'a', text: 'Debit'),
        QuestionOption(id: 'b', text: 'Credit'),
      ];
      final items = sortReviewItems(
        _sort([_card('q1', chose: 'a', correct: 'b')]),
        cards: const [
          SortItOutCard(id: 'q1', prompt: 'P', points: 10, options: options),
        ],
      );
      expect(items.single.yourAnswer, 'Debit');
      expect(items.single.correctAnswer, 'Credit');
      expect(items.single.isCorrect, isFalse);
    });

    test('is case-insensitive about the option id', () {
      const options = [QuestionOption(id: 'A', text: 'Debit')];
      final items = sortReviewItems(
        _sort([_card('q1', chose: 'a', correct: 'a')]),
        cards: const [
          SortItOutCard(id: 'q1', prompt: 'P', points: 10, options: options),
        ],
      );
      expect(items.single.correctAnswer, 'Debit');
    });

    test('falls back to the letter without the cards', () {
      final items = sortReviewItems(_sort([_card('q1', chose: 'a')]));
      expect(items.single.yourAnswer, 'A');
      expect(items.single.correctAnswer, 'B');
    });

    test('a timed out card says so', () {
      final items = sortReviewItems(_sort([_card('q1', timeout: true)]));
      expect(items.single.yourAnswer, "Time's up");
      expect(items.single.isCorrect, isFalse);
    });

    test('total time adds up the cards', () {
      expect(
        sortTotalTime(_sort([_card('a', ms: 1200), _card('b', ms: 800)])),
        const Duration(seconds: 2),
      );
    });
  });
}
