import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/quiz/presentation/screens/sudden_death_demo_screen.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sudden_death_question_view.dart';

Future<void> _pumpDemo(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SuddenDeathDemoScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitOption(WidgetTester tester, String optionId) async {
  final option = find.byKey(Key('sudden-option-$optionId'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pump();
  await tester.tap(find.text('Submit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('demo failure result is eliminated without celebration', (
    tester,
  ) async {
    await _pumpDemo(tester);

    await _submitOption(tester, 'b');

    expect(find.text('Eliminated'), findsOneWidget);
    expect(
      find.text('UI preview — no score or rewards were calculated'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<QuizCelebrationOverlay>(find.byType(QuizCelebrationOverlay))
          .enabled,
      isFalse,
    );
  });

  testWidgets('demo success result is cleared with celebration enabled', (
    tester,
  ) async {
    await _pumpDemo(tester);

    const correctAnswers = ['a', 'a', 'b', 'a', 'b', 'a', 'b', 'a', 'b', 'a'];
    for (final answer in correctAnswers) {
      await _submitOption(tester, answer);
    }

    expect(find.text('Sudden Death cleared'), findsOneWidget);
    expect(find.text('10 survived'), findsOneWidget);
    expect(
      tester
          .widget<QuizCelebrationOverlay>(find.byType(QuizCelebrationOverlay))
          .enabled,
      isTrue,
    );
  });

  testWidgets('demo timeout result is time up without celebration', (
    tester,
  ) async {
    await _pumpDemo(tester);

    await tester.pump(SuddenDeathConfig.questionTimeLimit);
    await tester.pumpAndSettle();

    expect(find.text("Time's up"), findsOneWidget);
    expect(
      tester
          .widget<QuizCelebrationOverlay>(find.byType(QuizCelebrationOverlay))
          .enabled,
      isFalse,
    );
  });
}
