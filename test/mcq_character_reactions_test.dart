import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_question_view.dart';

McqQuestion _question(String id, String prompt) => McqQuestion(
  id: id,
  topicId: 'topic',
  prompt: prompt,
  points: 10,
  options: const [
    QuestionOption(id: 'a', text: 'Revenue'),
    QuestionOption(id: 'b', text: 'Inventory'),
    QuestionOption(id: 'c', text: 'Expense'),
    QuestionOption(id: 'd', text: 'Capital'),
  ],
  correctOptionId: 'b',
);

Widget _app(McqQuestion question, List<Answer> submitted, {ThemeData? theme}) {
  return ProviderScope(
    overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(
        body: McqQuestionView(
          question: question,
          currentIndex: 0,
          totalQuestions: 3,
          currentStreak: 0,
          coins: 0,
          energy: 0,
          onExit: () {},
          onSubmit: submitted.add,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('companion goes idle, thinking, reaction, then resets', (
    tester,
  ) async {
    final submitted = <Answer>[];
    await tester.pumpWidget(
      _app(_question('q1', 'Which item is an asset?'), submitted),
    );
    await tester.pumpAndSettle();

    expect(find.text('Think carefully.'), findsOneWidget);

    await tester.tap(find.text('Inventory'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Need help?'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Great job!'), findsOneWidget);
    expect(submitted, isEmpty); // reaction is visible before moving on
    await tester.pumpAndSettle();
    expect(submitted, hasLength(1));

    // Next question resets the reaction.
    await tester.pumpWidget(
      _app(_question('q2', 'Second question?'), submitted),
    );
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsNothing);
    expect(find.text('Think carefully.'), findsOneWidget);
  });

  testWidgets('wrong answer gets an encouraging, not negative, reaction', (
    tester,
  ) async {
    final submitted = <Answer>[];
    await tester.pumpWidget(_app(_question('q1', 'Pick one'), submitted));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revenue'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Good try'), findsOneWidget);
    expect(find.text('Great job!'), findsNothing);
    await tester.pumpAndSettle();
    expect((submitted.single as McqAnswer).selectedOptionId, 'a');
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    for (final dark in [false, true]) {
      testWidgets('companion fits without overflow at ${size.width.toInt()}x'
          '${size.height.toInt()} ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            _question(
              'q1',
              'A very long question prompt that keeps going so the '
                  'character has to shrink and the options still have to fit '
                  'on screen without any overflow at all?',
            ),
            <Answer>[],
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mcq_character_section')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
