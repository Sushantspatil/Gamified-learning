import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sudden_death_question_view.dart';

const _question = SuddenDeathQuestion(
  id: 'sudden-1',
  topicId: 'web-dev-chapter-1-topic-1',
  prompt: 'Which tag creates a paragraph?',
  points: 15,
  options: [
    QuestionOption(id: 'a', text: '<div>'),
    QuestionOption(id: 'b', text: '<p>'),
    QuestionOption(id: 'c', text: '<img>'),
    QuestionOption(id: 'd', text: '<ul>'),
  ],
  correctOptionId: 'b',
);

Future<void> _pumpSuddenDeathView(
  WidgetTester tester, {
  void Function(Answer answer)? onSubmit,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          body: SuddenDeathQuestionView(
            key: UniqueKey(),
            question: _question,
            currentIndex: 0,
            totalQuestions: 5,
            currentStreak: 0,
            bestStreak: 0,
            energy: 0,
            coins: 100,
            onExit: () {},
            onSubmit: onSubmit ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _buyPowerUp(WidgetTester tester, String label) async {
  final key = switch (label) {
    '+5 SEC' => const Key('powerup-sudden-time'),
    '50:50' => const Key('powerup-sudden-50-50'),
    'Skip' => const Key('powerup-sudden-skip'),
    'Hint' => const Key('powerup-sudden-hint'),
    _ => throw ArgumentError('Unknown power-up: $label'),
  };
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buy & use'));
  await tester.pumpAndSettle();
}

Future<void> _tapOption(WidgetTester tester, String label) async {
  final optionId = _question.options
      .singleWhere((option) => option.text == label)
      .id;
  final target = find.byKey(Key('sudden-option-$optionId'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

void main() {
  testWidgets('renders question, urgency indicator, and power-ups', (
    tester,
  ) async {
    await _pumpSuddenDeathView(tester);

    expect(find.text('Sudden Death'), findsOneWidget);
    expect(find.text('Which tag creates a paragraph?'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.byKey(const Key('powerup-sudden-time')), findsOneWidget);
    expect(find.byKey(const Key('powerup-sudden-50-50')), findsOneWidget);
    expect(find.byKey(const Key('powerup-sudden-skip')), findsOneWidget);
    expect(find.byKey(const Key('powerup-sudden-hint')), findsOneWidget);
  });

  testWidgets('+5 SEC updates timer state', (tester) async {
    await _pumpSuddenDeathView(tester);

    await _buyPowerUp(tester, '+5 SEC');

    final boostedSecondIsVisible = [
      '16',
      '17',
      '18',
      '19',
      '20',
    ].any((value) => find.text(value).evaluate().isNotEmpty);
    expect(boostedSecondIsVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('50:50 removes incorrect options without revealing correctness', (
    tester,
  ) async {
    await _pumpSuddenDeathView(tester);

    await _buyPowerUp(tester, '50:50');

    expect(find.text('<p>'), findsOneWidget);
    expect(find.text('<div>'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('hint does not reveal the correct answer', (tester) async {
    await _pumpSuddenDeathView(tester);

    await _buyPowerUp(tester, 'Hint');

    expect(
      find.text(
        'Eliminate choices that do not match the strongest clue in the prompt.',
      ),
      findsOneWidget,
    );
    expect(find.text('Correct: <p>'), findsNothing);
  });

  testWidgets('skip advances safely through existing submission flow', (
    tester,
  ) async {
    SuddenDeathAnswer? submitted;
    await _pumpSuddenDeathView(
      tester,
      onSubmit: (answer) => submitted = answer as SuddenDeathAnswer,
    );

    await _buyPowerUp(tester, 'Skip');

    expect(submitted?.selectedOptionId, _question.correctOptionId);
  });

  testWidgets('correct and wrong answers submit after feedback', (
    tester,
  ) async {
    SuddenDeathAnswer? submitted;
    await _pumpSuddenDeathView(
      tester,
      onSubmit: (answer) => submitted = answer as SuddenDeathAnswer,
    );

    await _tapOption(tester, '<p>');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted?.selectedOptionId, 'b');

    submitted = null;
    await _pumpSuddenDeathView(
      tester,
      onSubmit: (answer) => submitted = answer as SuddenDeathAnswer,
    );
    await _tapOption(tester, '<div>');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted?.selectedOptionId, 'a');
  });

  testWidgets('timeout submits a failure answer', (tester) async {
    SuddenDeathAnswer? submitted;
    await _pumpSuddenDeathView(
      tester,
      onSubmit: (answer) => submitted = answer as SuddenDeathAnswer,
    );

    await tester.pump(SuddenDeathConfig.questionTimeLimit);
    await tester.pumpAndSettle();

    expect(submitted?.selectedOptionId, isNot(_question.correctOptionId));
  });
}
