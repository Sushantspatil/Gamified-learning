import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/domain/entities/sort_it_out_models.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sort_it_out_result_view.dart';

SortItOutCardReview _card(
  String id,
  String prompt, {
  String chose = 'b',
  String correct = 'b',
  bool timeout = false,
  int ms = 1200,
  String? explanation,
}) {
  final ok = chose == correct && !timeout;
  return SortItOutCardReview(
    question: id,
    prompt: prompt,
    selectedOption: timeout ? 'timeout' : chose,
    correctOption: correct,
    isCorrect: ok,
    isTimeout: timeout,
    timeTakenMs: ms,
    basePoints: ok ? 10 : 0,
    speedBonus: ok ? 5 : 0,
    comboBonus: 0,
    pointsEarned: ok ? 15 : 0,
    explanation: explanation,
  );
}

const _options = [
  QuestionOption(id: 'a', text: 'Debit'),
  QuestionOption(id: 'b', text: 'Credit'),
];

const _cards = [
  SortItOutCard(id: 'q1', prompt: 'Bank Loan', points: 10, options: _options),
  SortItOutCard(id: 'q2', prompt: 'Equipment', points: 10, options: _options),
  SortItOutCard(id: 'q3', prompt: 'Sales', points: 10, options: _options),
];

SortItOutResult _result({
  List<SortItOutCardReview>? cards,
  int total = 2,
  int correct = 2,
  int timeouts = 0,
  double accuracy = 100,
  int score = 30,
}) => SortItOutResult(
  session: 'sess-123',
  pairType: 'credit_debit',
  totalQuestions: total,
  correctCount: correct,
  timeoutCount: timeouts,
  bestStreak: 2,
  accuracyPercentage: accuracy,
  finalScore: score,
  coinsAwarded: 15,
  xpAwarded: 45,
  gemsAwarded: 2,
  level: const LevelProgressDto(
    current: 2,
    didLevelUp: true,
    experience: 150,
    nextLevelExp: 300,
  ),
  scoreBreakdown: const {
    'base_points': 20,
    'speed_bonus': 10,
    'combo_bonus': 0,
  },
  cardsReview:
      cards ??
      [
        _card('q1', 'Bank Loan', explanation: 'Bank Loan is a liability.'),
        _card('q2', 'Equipment', chose: 'a', correct: 'a', ms: 1400),
      ],
);

Future<void> _show(
  WidgetTester tester,
  SortItOutResult result, {
  VoidCallback? onDone,
  VoidCallback? onPlayAgain,
  List<SortItOutCard> cards = const [],
  ThemeData? theme,
  Size size = const Size(900, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = size.width < 500 ? 1 : 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      home: Scaffold(
        body: SortItOutResultView(
          result: result,
          cards: cards,
          onDone: onDone ?? () {},
          onPlayAgain: onPlayAgain,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SortItOutResultView', () {
    testWidgets('summary: celebration, score, three tiles, rewards', (
      tester,
    ) async {
      await _show(tester, _result());

      expect(find.byType(GameCelebrationOverlay), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.byKey(const Key('result_headline')), findsOneWidget);
      expect(find.text('2 OF 2 SORTED RIGHT'), findsOneWidget);

      final points = find.byKey(const Key('result_points'));
      expect(
        find.descendant(of: points, matching: find.text('30')),
        findsOneWidget,
      );
      expect(find.text('+45'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0:02'), findsOneWidget); // 1.2s + 1.4s
      expect(find.text('+15 Coins'), findsOneWidget);
      expect(find.text('+2 Gems'), findsOneWidget);
    });

    testWidgets('the card list and breakdown are not on the summary', (
      tester,
    ) async {
      await _show(tester, _result());

      expect(find.text('Answer review'), findsNothing);
      expect(find.text('Score Breakdown'), findsNothing);
      expect(find.text('Bank Loan'), findsNothing);
      expect(find.text('Official Score'), findsNothing);
    });

    testWidgets('a dot for every card, wrong ones in red', (tester) async {
      await _show(
        tester,
        _result(
          total: 3,
          correct: 1,
          timeouts: 1,
          accuracy: 33,
          cards: [
            _card('q1', 'Bank Loan', chose: 'a'),
            _card('q2', 'Equipment', chose: 'a', correct: 'a'),
            _card('q3', 'Sales', timeout: true),
          ],
        ),
      );

      expect(find.byKey(const Key('dot_2')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
      expect(find.text('Review your cards'), findsOneWidget);
    });

    testWidgets('the review shows only the missed cards, with category names', (
      tester,
    ) async {
      await _show(
        tester,
        _result(
          total: 3,
          correct: 1,
          timeouts: 1,
          accuracy: 33,
          cards: [
            _card(
              'q1',
              'Bank Loan',
              chose: 'a',
              explanation: 'A loan is a liability.',
            ),
            _card('q2', 'Equipment', chose: 'a', correct: 'a'),
            _card('q3', 'Sales', timeout: true),
          ],
        ),
        cards: _cards,
      );

      await tester.tap(find.byKey(const Key('answer_strip_tap')));
      await tester.pumpAndSettle();

      expect(find.text('Your cards'), findsOneWidget);
      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
      expect(find.byKey(const Key('review_item_2')), findsNothing);
      expect(find.byKey(const Key('review_item_3')), findsOneWidget);
      // The player chose "Debit", the right side was "Credit".
      expect(find.text('Debit'), findsOneWidget);
      expect(find.text('Credit'), findsNWidgets(2));
      expect(find.text("Time's up"), findsOneWidget);
      expect(find.text('A loan is a liability.'), findsOneWidget);
    });

    testWidgets('without the cards, sides are named A and B', (tester) async {
      await _show(
        tester,
        _result(
          total: 1,
          correct: 0,
          accuracy: 0,
          score: 0,
          cards: [_card('q1', 'Bank Loan', chose: 'a')],
        ),
      );
      await tester.tap(find.byKey(const Key('answer_strip_tap')));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('"Score details" shows the breakdown and the streak', (
      tester,
    ) async {
      await _show(tester, _result());

      await tester.tap(find.byKey(const Key('result_details_button')));
      await tester.pumpAndSettle();

      expect(find.text('Score Breakdown'), findsOneWidget);
      expect(find.text('Base Points'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Speed Bonus'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('Combo Bonus'), findsOneWidget);
      expect(find.text('Best streak: 2 in a row'), findsOneWidget);
    });

    testWidgets('Play again and Done work', (tester) async {
      var done = false;
      var again = false;
      await _show(
        tester,
        _result(),
        onDone: () => done = true,
        onPlayAgain: () => again = true,
      );
      await tester.tap(find.byKey(const Key('result_primary')));
      expect(again, isTrue);
      await tester.tap(find.byKey(const Key('result_secondary')));
      expect(done, isTrue);
    });

    testWidgets('fits a small screen in the light theme', (tester) async {
      await _show(
        tester,
        _result(),
        theme: AppTheme.lightTheme,
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('result_primary')), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
