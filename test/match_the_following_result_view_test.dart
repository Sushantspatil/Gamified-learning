import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/quiz/domain/entities/match_the_following_models.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/match_the_following_result_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';

MatchBoardReview _board(
  String code,
  String prompt, {
  required int matched,
  int mistakes = 0,
  bool timeout = false,
  int ms = 6500,
  String? explanation,
}) => MatchBoardReview(
  questionCode: code,
  prompt: prompt,
  pairsMatched: matched,
  totalPairs: 4,
  mistakes: mistakes,
  timeTakenMs: ms,
  isFlawless: matched == 4 && mistakes == 0 && !timeout,
  isTimeout: timeout,
  basePoints: 10,
  flawlessBonus: 5,
  speedBonus: 2,
  mistakePenalty: 0,
  totalBoardScore: 17,
  explanation: explanation,
);

MatchTheFollowingResult _result({
  List<MatchBoardReview>? boards,
  int matched = 8,
  int mistakes = 0,
  double accuracy = 100.0,
  int score = 35,
}) => MatchTheFollowingResult(
  session: 'match-sess-123',
  totalBoards: 2,
  clearedBoards: 2,
  totalPairsMatched: matched,
  totalPairsCount: 8,
  totalMistakes: mistakes,
  accuracyPercentage: accuracy,
  finalScore: score,
  coinsAwarded: 20,
  xpAwarded: 45,
  gemsAwarded: 3,
  level: const LevelProgressDto(
    current: 3,
    didLevelUp: true,
    experience: 200,
    nextLevelExp: 400,
  ),
  scoreBreakdown: const {
    'base_points': 20,
    'flawless_bonus': 10,
    'speed_bonus': 5,
    'mistake_penalty': 0,
  },
  boardsReview:
      boards ??
      [
        _board(
          'b1',
          'Accounting Equations & Definitions',
          matched: 4,
          explanation: 'Assets = Liabilities + Equity is fundamental.',
        ),
        _board('b2', 'Financial Statements Review', matched: 4, ms: 7200),
      ],
);

Future<void> _show(
  WidgetTester tester,
  MatchTheFollowingResult result, {
  VoidCallback? onDone,
  VoidCallback? onPlayAgain,
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
        body: MatchTheFollowingResultView(
          result: result,
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

  group('MatchTheFollowingResultView', () {
    testWidgets('summary: celebration, score, three tiles, rewards', (
      tester,
    ) async {
      await _show(tester, _result());

      expect(find.byType(GameCelebrationOverlay), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.byKey(const Key('result_headline')), findsOneWidget);
      expect(find.text('2 OF 2 BOARDS CLEARED'), findsOneWidget);

      final points = find.byKey(const Key('result_points'));
      expect(
        find.descendant(of: points, matching: find.text('35')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: points, matching: find.text('points')),
        findsOneWidget,
      );

      expect(find.text('+45'), findsOneWidget);
      expect(find.text('XP'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('ACCURACY'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('0:13'), findsOneWidget); // 6.5s + 7.2s
      expect(find.text('+20 Coins'), findsOneWidget);
      expect(find.text('+3 Gems'), findsOneWidget);
    });

    testWidgets('the long board list and breakdown are not on the summary', (
      tester,
    ) async {
      await _show(tester, _result());

      expect(find.text('Board review'), findsNothing);
      expect(find.text('Score Breakdown'), findsNothing);
      expect(find.text('Accounting Equations & Definitions'), findsNothing);
      expect(find.text('Official Score'), findsNothing);
    });

    testWidgets('a dot per board: green when flawless, red otherwise', (
      tester,
    ) async {
      await _show(
        tester,
        _result(
          boards: [
            _board('b1', 'One', matched: 4),
            _board('b2', 'Two', matched: 4, mistakes: 2),
          ],
          mistakes: 2,
          accuracy: 80,
        ),
      );

      expect(find.byKey(const Key('dot_0')), findsOneWidget);
      expect(find.byKey(const Key('dot_1')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Review your boards'), findsOneWidget);
    });

    testWidgets('the review opens on the boards that need work', (
      tester,
    ) async {
      await _show(
        tester,
        _result(
          boards: [
            _board('b1', 'Flawless one', matched: 4),
            _board(
              'b2',
              'Shaky one',
              matched: 4,
              mistakes: 2,
              ms: 18400,
              explanation: 'The cash book records only cash.',
            ),
            _board('b3', 'Too slow', matched: 2, mistakes: 1, timeout: true),
          ],
          mistakes: 3,
          accuracy: 80,
        ),
      );

      await tester.tap(find.byKey(const Key('answer_strip_tap')));
      await tester.pumpAndSettle();

      expect(find.text('Your boards'), findsOneWidget);
      expect(find.text('2 to improve, 1 flawless'), findsOneWidget);
      expect(find.text('Needs work (2)'), findsOneWidget);
      expect(find.byKey(const Key('review_item_1')), findsNothing);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);
      expect(find.byKey(const Key('review_item_3')), findsOneWidget);
      expect(find.text('Cleared with 2 mistakes, 18.4s'), findsOneWidget);
      expect(find.text("Time's up, 2 of 4 pairs"), findsOneWidget);
      expect(find.text('The cash book records only cash.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review_filter_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
      expect(find.text('Flawless, 4 of 4 pairs, 6.5s'), findsOneWidget);
    });

    testWidgets('"Score details" shows the score breakdown', (tester) async {
      await _show(tester, _result());

      await tester.tap(find.byKey(const Key('result_details_button')));
      await tester.pumpAndSettle();

      expect(find.text('Score Breakdown'), findsOneWidget);
      expect(find.text('Base Points'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Flawless Bonus'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('Speed Bonus'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('Mistake Penalty'), findsNothing);
      expect(find.text('Final Score'), findsOneWidget);
    });

    testWidgets('a mistake penalty shows up when there is one', (tester) async {
      await _show(
        tester,
        MatchTheFollowingResult(
          session: 's',
          totalBoards: 1,
          clearedBoards: 1,
          totalPairsMatched: 4,
          totalPairsCount: 4,
          totalMistakes: 2,
          accuracyPercentage: 66,
          finalScore: 16,
          coinsAwarded: 5,
          xpAwarded: 10,
          gemsAwarded: 0,
          scoreBreakdown: const {
            'base_points': 20,
            'flawless_bonus': 0,
            'speed_bonus': 0,
            'mistake_penalty': -4,
          },
        ),
      );
      await tester.tap(find.byKey(const Key('result_details_button')));
      await tester.pumpAndSettle();
      expect(find.text('Mistake Penalty'), findsOneWidget);
      expect(find.text('-4'), findsOneWidget);
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

    testWidgets('with no way to replay, Done is the main button', (
      tester,
    ) async {
      await _show(tester, _result());
      expect(find.byKey(const Key('result_secondary')), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('a game with nothing matched is calm, not celebratory', (
      tester,
    ) async {
      await _show(
        tester,
        _result(
          matched: 0,
          mistakes: 5,
          accuracy: 0,
          score: 0,
          boards: [_board('b1', 'One', matched: 0, mistakes: 5, timeout: true)],
        ),
      );
      expect(find.text('Keep going!'), findsOneWidget);
      expect(find.text('Every game makes you sharper'), findsOneWidget);
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
