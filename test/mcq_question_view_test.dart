import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_character_widget.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_question_view.dart';

const _question = McqQuestion(
  id: 'mcq-1',
  topicId: 'accountancy-chapter-1-topic-1',
  prompt: 'Which item is an asset?',
  points: 10,
  options: [
    QuestionOption(id: 'a', text: 'Revenue'),
    QuestionOption(id: 'b', text: 'Inventory'),
    QuestionOption(id: 'c', text: 'Expense'),
    QuestionOption(id: 'd', text: 'Capital'),
  ],
  correctOptionId: 'b',
  hint: 'Think about items a business owns or can sell.',
);

const _nextQuestion = McqQuestion(
  id: 'mcq-2',
  topicId: 'accountancy-chapter-1-topic-1',
  prompt: 'Which tag creates a paragraph?',
  points: 10,
  options: [
    QuestionOption(id: 'a', text: '<div>'),
    QuestionOption(id: 'b', text: '<p>'),
    QuestionOption(id: 'c', text: '<span>'),
    QuestionOption(id: 'd', text: '<main>'),
  ],
  correctOptionId: 'b',
  hint: 'Think about semantic text blocks.',
);

Future<void> _pumpMcqView(
  WidgetTester tester, {
  void Function(Answer answer)? onSubmit,
  McqQuestion question = _question,
  int currentIndex = 0,
  int totalQuestions = 2,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          body: McqQuestionView(
            question: question,
            currentIndex: currentIndex,
            totalQuestions: totalQuestions,
            currentStreak: 0,
            coins: 60,
            energy: 0,
            onExit: () {},
            onSubmit: onSubmit ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await _pumpAnimations(tester);
}

Future<void> _pumpAnimations(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _confirmPowerUp(WidgetTester tester) async {
  final buyButton = find.text('Buy & use');
  await tester.ensureVisible(buyButton);
  await _pumpAnimations(tester);
  await tester.tap(buyButton);
  await _pumpAnimations(tester);
}

void main() {
  testWidgets('MCQ renders with assistance controls', (tester) async {
    await _pumpMcqView(tester);

    expect(find.text('Which item is an asset?'), findsOneWidget);
    expect(find.byKey(const Key('mcq_character_section')), findsOneWidget);
    expect(find.text('Think carefully.'), findsOneWidget);
    expect(find.text('50:50'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
  });

  testWidgets('character is positioned between question and options', (
    tester,
  ) async {
    await _pumpMcqView(tester);

    final questionTop = tester
        .getTopLeft(find.text('Which item is an asset?'))
        .dy;
    final characterTop = tester
        .getTopLeft(find.byKey(const Key('mcq_character_section')))
        .dy;
    final firstOptionTop = tester.getTopLeft(find.text('Revenue')).dy;
    final powerUpTop = tester
        .getTopLeft(find.byKey(const Key('game_power_up_bar')))
        .dy;

    expect(characterTop, greaterThan(questionTop));
    expect(firstOptionTop, greaterThan(characterTop));
    expect(powerUpTop, greaterThan(firstOptionTop));
  });

  testWidgets('question and options keep their entry animations', (
    tester,
  ) async {
    await _pumpMcqView(tester);

    expect(find.byKey(const Key('mcq_question_motion')), findsOneWidget);
    for (var index = 0; index < _question.options.length; index++) {
      expect(find.byKey(Key('mcq_option_stagger_$index')), findsOneWidget);
    }
  });

  testWidgets('options remain tappable and update character state', (
    tester,
  ) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('Inventory'));
    await _pumpAnimations(tester);

    expect(find.text('Nice choice.'), findsOneWidget);
  });

  testWidgets('50:50 removes two incorrect options only', (tester) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('50:50'));
    await _pumpAnimations(tester);
    await _confirmPowerUp(tester);

    expect(find.text('Removed by 50:50'), findsNothing);
    expect(find.text('Revenue'), findsNothing);
    expect(find.text('Expense'), findsNothing);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text("Let's narrow it down."), findsOneWidget);
    expect(find.text('Capital'), findsOneWidget);
  });

  testWidgets('hint does not reveal the correct answer', (tester) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('Hint'));
    await _pumpAnimations(tester);
    await _confirmPowerUp(tester);

    expect(
      find.text('Think about items a business owns or can sell.'),
      findsOneWidget,
    );
    expect(
      tester.widget<McqCharacterWidget>(find.byType(McqCharacterWidget)).state,
      McqCharacterState.thinking,
    );
    expect(find.text('Correct: Inventory'), findsNothing);
  });

  testWidgets('skip transitions the character and submits without revealing', (
    tester,
  ) async {
    McqAnswer? submitted;
    await _pumpMcqView(
      tester,
      onSubmit: (answer) => submitted = answer as McqAnswer,
    );

    await tester.tap(find.text('Skip'));
    await _pumpAnimations(tester);
    await _confirmPowerUp(tester);

    expect(submitted?.selectedOptionId, isNot(_question.correctOptionId));
    expect(find.text('Next one!'), findsOneWidget);
    expect(find.text('Correct: Inventory'), findsNothing);
  });

  testWidgets('MCQ layout avoids overflow on common portrait size', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = oldOnError);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMcqView(tester);

    expect(
      errors.where(
        (error) =>
            error.exceptionAsString().contains('A RenderFlex overflowed'),
      ),
      isEmpty,
    );
  });

  testWidgets('selected option can change and remains neutral before submit', (
    tester,
  ) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('Revenue'));
    await _pumpAnimations(tester);
    await tester.tap(find.text('Inventory'));
    await _pumpAnimations(tester);

    expect(find.text('Correct: Inventory'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('lifelines cannot be used after answer submission', (
    tester,
  ) async {
    McqAnswer? submitted;
    await _pumpMcqView(
      tester,
      onSubmit: (answer) => submitted = answer as McqAnswer,
    );

    await tester.tap(find.text('Inventory'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await _pumpAnimations(tester);
    await tester.tap(find.text('50:50'));
    await tester.tap(find.text('Hint'));
    await _pumpAnimations(tester);

    expect(submitted?.selectedOptionId, 'b');
    expect(find.text('Removed by 50:50'), findsNothing);
    expect(
      find.text('Think about items a business owns or can sell.'),
      findsNothing,
    );
  });

  testWidgets('final question shows Submit quiz', (tester) async {
    await _pumpMcqView(tester, currentIndex: 1, totalQuestions: 2);

    expect(find.text('Submit quiz'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('question change resets companion state and animations', (
    tester,
  ) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('Inventory'));
    await _pumpAnimations(tester);
    expect(find.text('Nice choice.'), findsOneWidget);

    await _pumpMcqView(
      tester,
      question: _nextQuestion,
      currentIndex: 1,
      totalQuestions: 2,
    );

    expect(find.text('Which tag creates a paragraph?'), findsOneWidget);
    expect(find.text('Think carefully.'), findsOneWidget);
    expect(find.byKey(const Key('mcq_question_motion')), findsOneWidget);
  });

  testWidgets('skip submits a neutral missed answer through existing flow', (
    tester,
  ) async {
    McqAnswer? submitted;
    await _pumpMcqView(
      tester,
      onSubmit: (answer) => submitted = answer as McqAnswer,
    );

    await tester.tap(find.text('Skip'));
    await _pumpAnimations(tester);
    await _confirmPowerUp(tester);

    expect(submitted?.selectedOptionId, isNot(_question.correctOptionId));
    expect(find.text('Correct: Inventory'), findsNothing);
  });
}
