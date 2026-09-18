import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_result.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_result_view.dart';

void main() {
  testWidgets('renders score and reward breakdown from backend result', (
    tester,
  ) async {
    await _pumpResult(tester, _result());

    expect(find.text('Quiz Complete!'), findsOneWidget);
    expect(find.text('40 / 50'), findsOneWidget);
    expect(find.text('4 correct'), findsOneWidget);
    expect(find.text('1 wrong'), findsOneWidget);
    expect(find.text('80% accuracy'), findsOneWidget);
    expect(find.text('+40 XP'), findsNWidgets(2));
    expect(find.text('+15 Coins'), findsOneWidget);
    expect(find.text('Level 4'), findsOneWidget);
    expect(find.text('340 / 500 XP'), findsOneWidget);
    expect(find.text('Quiz completion'), findsWidgets);
    expect(find.text('+20 XP'), findsNWidgets(2));
    expect(find.text('+20 pts'), findsNothing);
    expect(find.text('+40 pts'), findsOneWidget);
    expect(find.text('Accuracy bonus'), findsOneWidget);
  });

  testWidgets('hides zero value reward rows', (tester) async {
    await _pumpResult(tester, _result());

    expect(find.text('Perfect score bonus'), findsNothing);
    expect(find.text('+0 XP'), findsNothing);
  });

  testWidgets('opens scoring explanation sheet', (tester) async {
    await _pumpResult(tester, _result());

    await tester.ensureVisible(find.text('How scoring works'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How scoring works'));
    await tester.pumpAndSettle();

    expect(find.text('Points'), findsWidgets);
    expect(
      find.text('Earned from correct answers in this quiz.'),
      findsOneWidget,
    );
    expect(find.text('Helps increase your account level.'), findsOneWidget);
    expect(find.text('Can be used for power-ups.'), findsOneWidget);
  });
}

Future<void> _pumpResult(WidgetTester tester, QuizResult result) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: QuizResultView(result: result, onDone: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

QuizResult _result() {
  return QuizResult(
    sessionId: 'session-1',
    topicId: 'topic-1',
    quizType: QuestionType.mcq,
    score: const Score(
      earnedPoints: 40,
      maxPoints: 50,
      correctCount: 4,
      totalCount: 5,
    ),
    records: const [],
    endedEarly: false,
    streakCount: 0,
    xpAwarded: 40,
    coinsAwarded: 15,
    rewardBreakdown: const QuizRewardBreakdown(
      score: [
        RewardBreakdownItem(key: 'correct_answer_points', amount: 40),
        RewardBreakdownItem(key: 'bonus_points', amount: 0),
      ],
      xp: [
        RewardBreakdownItem(key: 'completion_xp', amount: 20),
        RewardBreakdownItem(key: 'correct_answer_xp', amount: 20),
        RewardBreakdownItem(key: 'perfect_bonus_xp', amount: 0),
      ],
      coins: [
        RewardBreakdownItem(key: 'completion_coins', amount: 10),
        RewardBreakdownItem(key: 'accuracy_bonus_coins', amount: 5),
      ],
    ),
    levelProgress: const QuizLevelProgress(
      currentLevel: 4,
      experience: 340,
      nextLevelExperience: 500,
    ),
    timeTaken: const Duration(minutes: 1),
    createdAt: DateTime(2026),
  );
}
