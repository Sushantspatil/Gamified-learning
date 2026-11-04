import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sudden_death_question_view.dart';
import 'package:skillverse_app/shared/widgets/game_header.dart';
import 'package:skillverse_app/shared/widgets/quit_game_dialog.dart';

Widget _app(Widget child, {ThemeData? theme}) => ProviderScope(
  child: MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    home: Scaffold(body: child),
  ),
);

void main() {
  group('shared game header', () {
    testWidgets('shows the mode, coins, counter and a progress bar, no arrow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Padding(
            padding: EdgeInsets.all(16),
            child: GameHeader(
              title: 'Sort It Out',
              coins: 2799,
              currentIndex: 2,
              totalQuestions: 10,
              progress: 0.3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sort It Out'), findsOneWidget);
      expect(find.text('2799'), findsOneWidget);
      expect(find.text('3 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.bySemanticsLabel('Sort It Out progress'), findsOneWidget);
    });

    testWidgets('a long title and big text still fit a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: GameHeader(
                title: 'Match the Following Challenge',
                coins: 123456,
                currentIndex: 9,
                totalQuestions: 10,
                progress: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('10 / 10'), findsOneWidget);
    });
  });

  group('quit popup', () {
    Future<bool?> ask(WidgetTester tester, String tapLabel) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    answer = await confirmQuitGame(context, mode: 'Match It'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Quit Match It?'), findsOneWidget);
      expect(
        find.text('Your progress in this round will be lost.'),
        findsOneWidget,
      );
      await tester.tap(find.text(tapLabel));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('Keep playing stays', (tester) async {
      expect(await ask(tester, 'Keep playing'), isFalse);
    });

    testWidgets('Quit leaves', (tester) async {
      expect(await ask(tester, 'Quit'), isTrue);
    });
  });

  testWidgets('Sudden Death uses the shared header and a compact status row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const question = SuddenDeathQuestion(
      id: 'sd-1',
      prompt: '10 - 4 = ?',
      points: 10,
      options: [
        QuestionOption(id: 'a', text: '6'),
        QuestionOption(id: 'b', text: '5'),
      ],
      correctOptionId: 'a',
      topicId: 'mental-maths',
    );
    await tester.pumpWidget(
      _app(
        SuddenDeathQuestionView(
          question: question,
          currentIndex: 0,
          totalQuestions: 10,
          currentStreak: 3,
          bestStreak: 5,
          energy: 224,
          coins: 2799,
          onExit: () {},
          isPreviewMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GameHeader), findsOneWidget);
    expect(find.text('Sudden Death'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget); // once: the header only
    expect(find.text('2799'), findsWidgets);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Best streak: 5'), findsOneWidget);
    expect(find.text('One wrong answer ends the run.'), findsOneWidget);
    expect(
      find.text('One wrong answer'),
      findsNothing,
    ); // the big banner is gone
    expect(tester.takeException(), isNull);
  });
}
