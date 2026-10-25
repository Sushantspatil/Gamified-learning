import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_result.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_result_view.dart';

QuizResult _createResult({
  String sessionId = 'session-123',
  QuestionType quizType = QuestionType.mcq,
  int correct = 5,
  int total = 10,
  int earnedPoints = 50,
  int maxPoints = 100,
  bool endedEarly = false,
  bool? completedSuccessfully = true,
}) {
  return QuizResult(
    sessionId: sessionId,
    topicId: 'topic-1',
    quizType: quizType,
    score: Score(
      earnedPoints: earnedPoints,
      maxPoints: maxPoints,
      correctCount: correct,
      totalCount: total,
    ),
    records: const [],
    endedEarly: endedEarly,
    completedSuccessfully: completedSuccessfully,
    streakCount: correct,
    xpAwarded: 25,
    coinsAwarded: 10,
    timeTaken: const Duration(seconds: 45),
    createdAt: DateTime.now(),
  );
}

Widget _buildWrapper({
  required Widget child,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: disableAnimations,
      accessibleNavigation: accessibleNavigation,
      size: const Size(800, 1200),
    ),
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameCelebrationOverlay — Mode Selection & Poppers Integration', () {
    testWidgets(
      'MCQ ordinary completed game renders standard multi-popper celebration',
      (tester) async {
        final result = _createResult(
          quizType: QuestionType.mcq,
          correct: 7,
          total: 10,
        );

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: result, onDone: () {}),
          ),
        );
        await tester.pump();

        final overlay = tester.widget<GameCelebrationOverlay>(
          find.byType(GameCelebrationOverlay),
        );
        expect(overlay.type, CelebrationType.standard);
        expect(find.text('Quiz Complete!'), findsOneWidget);
      },
    );

    testWidgets(
      'Match the Following completed game renders standard multi-popper celebration',
      (tester) async {
        final result = _createResult(
          quizType: QuestionType.matchTheFollowing,
          correct: 4,
          total: 5,
        );

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: result, onDone: () {}),
          ),
        );
        await tester.pump();

        final overlay = tester.widget<GameCelebrationOverlay>(
          find.byType(GameCelebrationOverlay),
        );
        expect(overlay.type, CelebrationType.standard);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      'Sort It Out completed game renders standard multi-popper celebration',
      (tester) async {
        final result = _createResult(
          quizType: QuestionType.sortItRight,
          correct: 4,
          total: 5,
        );

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: result, onDone: () {}),
          ),
        );
        await tester.pump();

        final overlay = tester.widget<GameCelebrationOverlay>(
          find.byType(GameCelebrationOverlay),
        );
        expect(overlay.type, CelebrationType.standard);
        expect(find.text('Sort It Out - Results'), findsOneWidget);
      },
    );

    testWidgets(
      'Perfect score across any mode triggers enhanced perfect celebration with gold highlights',
      (tester) async {
        final perfectResult = _createResult(
          quizType: QuestionType.mcq,
          correct: 10,
          total: 10,
          earnedPoints: 100,
          maxPoints: 100,
          endedEarly: false,
        );

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: perfectResult, onDone: () {}),
          ),
        );
        await tester.pump();

        final overlay = tester.widget<GameCelebrationOverlay>(
          find.byType(GameCelebrationOverlay),
        );
        expect(overlay.type, CelebrationType.perfect);
      },
    );

    testWidgets(
      'Unsuccessful Sudden Death run (endedEarly=true) triggers subdued atmosphere without false victory cannon',
      (tester) async {
        final suddenDeathFailed = _createResult(
          quizType: QuestionType.suddenDeath,
          correct: 2,
          total: 3,
          endedEarly: true,
          completedSuccessfully: false,
        );

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: suddenDeathFailed, onDone: () {}),
          ),
        );
        await tester.pump();

        final overlay = tester.widget<GameCelebrationOverlay>(
          find.byType(GameCelebrationOverlay),
        );
        expect(overlay.type, CelebrationType.subdued);
        expect(find.text('Sudden Death - Quiz Ended'), findsOneWidget);
      },
    );

    testWidgets(
      'Zero correct answers triggers subdued celebration rather than victory cannons',
      (tester) async {
        final zeroResult = _createResult(
          correct: 0,
          total: 5,
          earnedPoints: 0,
        );

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: zeroResult, onDone: () {}),
          ),
        );
        await tester.pump();

        final overlay = tester.widget<GameCelebrationOverlay>(
          find.byType(GameCelebrationOverlay),
        );
        expect(overlay.type, CelebrationType.subdued);
      },
    );
  });

  group('GameCelebrationOverlay — Lifecycle, Single-Trigger & Accessibility', () {
    testWidgets(
      'Celebration triggers once per presentation and widget rebuilds do not duplicate bursts',
      (tester) async {
        var counter = 0;
        final result = _createResult(sessionId: 'session-stable-1');

        await tester.pumpWidget(
          _buildWrapper(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Text('Rebuilds: $counter'),
                    ElevatedButton(
                      onPressed: () => setState(() => counter++),
                      child: const Text('Rebuild'),
                    ),
                    Expanded(
                      child: QuizResultView(result: result, onDone: () {}),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Rebuild parent tree multiple times
        await tester.tap(find.text('Rebuild'));
        await tester.pump();
        await tester.tap(find.text('Rebuild'));
        await tester.pump();

        expect(find.text('Rebuilds: 2'), findsOneWidget);
        // Celebration overlay maintains single session key
        expect(
          find.byKey(const ValueKey('celebration-session-stable-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Genuine new session triggers a new celebration instance',
      (tester) async {
        final resultSession1 = _createResult(sessionId: 'session-first');
        final resultSession2 = _createResult(sessionId: 'session-second');

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: resultSession1, onDone: () {}),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('celebration-session-first')),
          findsOneWidget,
        );

        // Switch to session 2
        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(result: resultSession2, onDone: () {}),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('celebration-session-second')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Reduced-motion setting (disableAnimations=true) immediately suppresses particles and renders clean static view',
      (tester) async {
        final result = _createResult();

        await tester.pumpWidget(
          _buildWrapper(
            disableAnimations: true,
            accessibleNavigation: false,
            child: QuizResultView(result: result, onDone: () {}),
          ),
        );
        await tester.pump();

        // Under genuine reduceMotion, GameCelebrationOverlay suppresses celebration particle and glow canvases
        expect(
          find.byKey(const Key('celebration-particles-canvas')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('celebration-glow-canvas')),
          findsNothing,
        );
        expect(find.text('Quiz Complete!'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets(
      'Samsung TalkBack (accessibleNavigation=true, disableAnimations=false) keeps animations intact',
      (tester) async {
        final result = _createResult();

        await tester.pumpWidget(
          _buildWrapper(
            disableAnimations: false,
            accessibleNavigation: true,
            child: QuizResultView(result: result, onDone: () {}),
          ),
        );
        await tester.pump();

        // Celebration animations remain fully enabled with celebration particles canvas
        expect(
          find.byKey(const Key('celebration-particles-canvas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('celebration-glow-canvas')),
          findsOneWidget,
        );
        expect(find.text('Quiz Complete!'), findsOneWidget);
      },
    );

    testWidgets(
      'Result-screen buttons remain fully interactive during and after celebration',
      (tester) async {
        var doneClicked = false;
        var playAgainClicked = false;
        final result = _createResult(quizType: QuestionType.sortItRight);

        await tester.pumpWidget(
          _buildWrapper(
            child: QuizResultView(
              result: result,
              onDone: () => doneClicked = true,
              onPlayAgain: () => playAgainClicked = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // IgnorePointer wraps celebration particles so buttons remain clickable
        await tester.ensureVisible(find.text('Play again'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Play again'));
        expect(playAgainClicked, isTrue);

        await tester.ensureVisible(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        expect(doneClicked, isTrue);
      },
    );
  });
}
