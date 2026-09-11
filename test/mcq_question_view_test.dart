import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MCQ renders with assistance controls', (tester) async {
    await _pumpMcqView(tester);

    expect(find.text('Which item is an asset?'), findsOneWidget);
    expect(find.text('50:50'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
  });

  testWidgets('50:50 removes two incorrect options only', (tester) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('50:50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy & use'));
    await tester.pumpAndSettle();

    expect(find.text('Removed by 50:50'), findsNothing);
    expect(find.text('Revenue'), findsNothing);
    expect(find.text('Expense'), findsNothing);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Capital'), findsOneWidget);
  });

  testWidgets('hint does not reveal the correct answer', (tester) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy & use'));
    await tester.pumpAndSettle();

    expect(
      find.text('Think about items a business owns or can sell.'),
      findsOneWidget,
    );
    expect(find.text('Correct: Inventory'), findsNothing);
  });

  testWidgets('selected option can change and remains neutral before submit', (
    tester,
  ) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(find.text('50:50'));
    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();

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

  testWidgets('skip submits a neutral missed answer through existing flow', (
    tester,
  ) async {
    McqAnswer? submitted;
    await _pumpMcqView(
      tester,
      onSubmit: (answer) => submitted = answer as McqAnswer,
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy & use'));
    await tester.pumpAndSettle();

    expect(submitted?.selectedOptionId, isNot(_question.correctOptionId));
    expect(find.text('Correct: Inventory'), findsNothing);
  });
}
