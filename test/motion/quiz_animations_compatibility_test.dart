import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_character_widget.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sort_it_right_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/match_the_following_view.dart';
import 'package:skillverse_app/shared/widgets/animated_count_text.dart';
import 'package:skillverse_app/shared/widgets/app_progress_bar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Quiz Animation Compatibility with Samsung / Accessible Navigation', () {
    testWidgets(
      'McqCharacterWidget animates and properly responds to app lifecycle state',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MediaQuery(
              data: MediaQueryData(
                disableAnimations: false,
                accessibleNavigation: true, // TalkBack enabled
              ),
              child: Scaffold(
                body: McqCharacterWidget(
                  state: McqCharacterState.idle,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Character section must be visible and rendered
        expect(find.byKey(const Key('mcq_character_section')), findsOneWidget);
        expect(find.byKey(const Key('mcq_scholar_companion_art')), findsOneWidget);

        // Simulate app entering background
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        // Simulate app resuming
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SortItRightView card falling is NOT frozen when accessibleNavigation is true',
      (tester) async {
        const question = SortItRightQuestion(
          id: 'sort_q1',
          topicId: 'accounting_101',
          prompt: 'Sort into Assets vs Liabilities',
          points: 10,
          leftCategory: 'Assets',
          rightCategory: 'Liabilities',
          itemsInOrder: ['Cash', 'Loan'],
          correctSides: [SortSide.left, SortSide.right],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  disableAnimations: false,
                  accessibleNavigation: true, // TalkBack on Samsung
                ),
                child: Scaffold(
                  body: SortItRightView(
                    question: question,
                    currentIndex: 0,
                    totalQuestions: 1,
                    currentStreak: 0,
                    coins: 100,
                    energy: 5,
                    onExit: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Start sorting'), findsOneWidget);

        // Tap Start sorting to transition into falling phase
        await tester.tap(find.text('Start sorting'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Assets'), findsOneWidget);
        expect(find.text('Liabilities'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'MatchTheFollowingView initializes properly with accessibleNavigation: true',
      (tester) async {
        const question = MatchTheFollowingQuestion(
          id: 'match_q1',
          topicId: 'accounting_101',
          prompt: 'Match items',
          points: 10,
          pairs: [
            MatchPair(id: 'p1', left: 'Assets', right: 'Debit'),
            MatchPair(id: 'p2', left: 'Liabilities', right: 'Credit'),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  disableAnimations: false,
                  accessibleNavigation: true,
                ),
                child: Scaffold(
                  body: MatchTheFollowingView(
                    question: question,
                    currentIndex: 0,
                    totalQuestions: 1,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Match items'), findsOneWidget);
        expect(find.text('Assets'), findsOneWidget);
        expect(find.text('Liabilities'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AnimatedCountText and AppProgressBar animate when accessibleNavigation is true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MediaQuery(
              data: MediaQueryData(
                disableAnimations: false,
                accessibleNavigation: true,
              ),
              child: Scaffold(
                body: Column(
                  children: [
                    AnimatedCountText(value: 500, suffix: ' pts'),
                    AppProgressBar(value: 0.65),
                  ],
                ),
              ),
            ),
          ),
        );

        // Before animation finishes
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(AnimatedCountText), findsOneWidget);
        expect(find.byType(AppProgressBar), findsOneWidget);

        // Settle animation
        await tester.pumpAndSettle();
        expect(find.text('500 pts'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
