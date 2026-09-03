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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          body: McqQuestionView(
            question: _question,
            currentIndex: 0,
            totalQuestions: 1,
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
    expect(find.text('Inventory'), findsOneWidget);
  });

  testWidgets('50:50 removes two incorrect options only', (tester) async {
    await _pumpMcqView(tester);

    await tester.tap(find.text('50:50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy & use'));
    await tester.pumpAndSettle();

    expect(find.text('Removed by 50:50'), findsNWidgets(2));
    expect(find.text('Inventory'), findsOneWidget);
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
    await tester.tap(find.text('Submit Answer'));
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
}
