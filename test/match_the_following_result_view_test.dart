import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/quiz/domain/entities/match_the_following_models.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/match_the_following_result_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyResult = MatchTheFollowingResult(
    session: 'match-sess-123',
    totalBoards: 2,
    clearedBoards: 2,
    totalPairsMatched: 8,
    totalPairsCount: 8,
    totalMistakes: 0,
    accuracyPercentage: 100.0,
    finalScore: 35,
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
    boardsReview: const [
      MatchBoardReview(
        questionCode: 'b1',
        prompt: 'Accounting Equations & Definitions',
        pairsMatched: 4,
        totalPairs: 4,
        mistakes: 0,
        timeTakenMs: 6500,
        isFlawless: true,
        isTimeout: false,
        basePoints: 10,
        flawlessBonus: 5,
        speedBonus: 2,
        mistakePenalty: 0,
        totalBoardScore: 17,
        explanation: 'Assets = Liabilities + Equity is fundamental.',
      ),
      MatchBoardReview(
        questionCode: 'b2',
        prompt: 'Financial Statements Review',
        pairsMatched: 4,
        totalPairs: 4,
        mistakes: 0,
        timeTakenMs: 7200,
        isFlawless: true,
        isTimeout: false,
        basePoints: 10,
        flawlessBonus: 5,
        speedBonus: 3,
        mistakePenalty: 0,
        totalBoardScore: 18,
        explanation: 'Balance sheet portrays snapshot at a date.',
      ),
    ],
  );

  group('MatchTheFollowingResultView — Unified Result UI & Visual Styling', () {
    testWidgets(
      'renders celebration overlay, score banner, metric pills, rewards, breakdown, and board review',
      (tester) async {
        var doneTapped = false;
        var playAgainTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: MatchTheFollowingResultView(
                  result: dummyResult,
                  onDone: () => doneTapped = true,
                  onPlayAgain: () => playAgainTapped = true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Overlay & Emblem
        expect(find.byType(GameCelebrationOverlay), findsOneWidget);
        expect(find.byIcon(Icons.emoji_events), findsOneWidget);

        // 2. Title & Subtitle
        expect(find.text('Match the Following — Results'), findsOneWidget);
        expect(find.text('2 of 2 boards cleared'), findsOneWidget);

        // 3. Official Score Panel
        expect(find.text('Official Score'), findsOneWidget);
        expect(find.text('35'), findsAtLeast(1));

        // 4. Metric Pills
        expect(find.text('8 / 8 pairs'), findsOneWidget);
        expect(find.text('2 / 2 boards'), findsOneWidget);
        expect(find.text('100% Accuracy'), findsOneWidget);

        // 5. Economy Reward Chips
        expect(find.text('+45 XP'), findsOneWidget);
        expect(find.text('+20 Coins'), findsOneWidget);
        expect(find.text('+3 Gems'), findsOneWidget);
        expect(find.text('Level 3 Up!'), findsOneWidget);

        // 6. Score Breakdown
        expect(find.text('Score Breakdown'), findsOneWidget);
        expect(find.text('Base Points'), findsOneWidget);
        expect(find.text('+20'), findsOneWidget);
        expect(find.text('Flawless Bonus'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);
        expect(find.text('Speed Bonus'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);

        // 7. Board Reviews & Explanations
        expect(find.text('Board review'), findsOneWidget);
        expect(find.text('Accounting Equations & Definitions'), findsOneWidget);
        expect(
          find.text('Assets = Liabilities + Equity is fundamental.'),
          findsOneWidget,
        );

        // 8. Buttons
        final playAgainBtn = find.text('Play again');
        await tester.ensureVisible(playAgainBtn);
        await tester.tap(playAgainBtn);
        expect(playAgainTapped, isTrue);

        final doneBtn = find.text('Done');
        await tester.ensureVisible(doneBtn);
        await tester.tap(doneBtn);
        expect(doneTapped, isTrue);
      },
    );

    testWidgets('responsive layout on small screen (360x640) in light theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: MatchTheFollowingResultView(
                result: dummyResult,
                onDone: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Match the Following — Results'), findsOneWidget);
      expect(find.text('Official Score'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}

