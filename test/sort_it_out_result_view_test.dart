import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/quiz/domain/entities/sort_it_out_models.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sort_it_out_result_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyResult = SortItOutResult(
    session: 'sess-123',
    pairType: 'credit_debit',
    totalQuestions: 2,
    correctCount: 2,
    timeoutCount: 0,
    bestStreak: 2,
    accuracyPercentage: 100.0,
    finalScore: 30,
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
    cardsReview: const [
      SortItOutCardReview(
        question: 'q1',
        prompt: 'Bank Loan',
        selectedOption: 'b',
        correctOption: 'b',
        isCorrect: true,
        isTimeout: false,
        timeTakenMs: 1200,
        basePoints: 10,
        speedBonus: 5,
        comboBonus: 0,
        pointsEarned: 15,
        explanation: 'Bank Loan is a liability (credit).',
      ),
      SortItOutCardReview(
        question: 'q2',
        prompt: 'Equipment',
        selectedOption: 'a',
        correctOption: 'a',
        isCorrect: true,
        isTimeout: false,
        timeTakenMs: 1400,
        basePoints: 10,
        speedBonus: 5,
        comboBonus: 0,
        pointsEarned: 15,
        explanation: 'Equipment is an asset (debit).',
      ),
    ],
  );

  group('SortItOutResultView — Unified Result UI & Visual Styling', () {
    testWidgets(
      'renders celebration overlay, score banner, metric pills, rewards, breakdown, and cards',
      (tester) async {
        var doneTapped = false;
        var playAgainTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SortItOutResultView(
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
        expect(find.text('Sort It Out — Results'), findsOneWidget);
        expect(find.text('2 of 2 correct'), findsOneWidget);

        // 3. Score
        expect(find.text('Official Score'), findsOneWidget);
        expect(find.text('30'), findsAtLeast(1));

        // 4. Metric pills
        expect(find.text('2 correct'), findsOneWidget);
        expect(find.text('0 wrong'), findsOneWidget);
        expect(find.text('100% Accuracy'), findsOneWidget);
        expect(find.text('🔥 2 Best Streak'), findsOneWidget);

        // 5. Rewards
        expect(find.text('+45 XP'), findsOneWidget);
        expect(find.text('+15 Coins'), findsOneWidget);
        expect(find.text('+2 Gems'), findsOneWidget);
        expect(find.text('Level Up!'), findsOneWidget);

        // 6. Authoritative Breakdown
        expect(find.text('Score Breakdown'), findsOneWidget);
        expect(find.text('Base Points'), findsOneWidget);
        expect(find.text('+20'), findsOneWidget);
        expect(find.text('Speed Bonus'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);

        // 7. Cards Review
        expect(find.text('Answer review'), findsOneWidget);
        expect(find.text('Bank Loan'), findsOneWidget);
        expect(find.text('Correct: B'), findsOneWidget);
        expect(find.text('Equipment'), findsOneWidget);
        expect(find.text('Correct: A'), findsOneWidget);
        expect(find.text('Bank Loan is a liability (credit).'), findsOneWidget);

        // 8. Buttons
        expect(find.text('Play again'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);

        await tester.ensureVisible(find.text('Play again'));
        await tester.tap(find.text('Play again'));
        expect(playAgainTapped, isTrue);

        await tester.ensureVisible(find.text('Done'));
        await tester.tap(find.text('Done'));
        expect(doneTapped, isTrue);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders cleanly on small viewport (360x640) and Light Theme without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SortItOutResultView(
                  result: dummyResult,
                  onDone: () {},
                  onPlayAgain: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Sort It Out — Results'), findsOneWidget);
        expect(find.text('Official Score'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
