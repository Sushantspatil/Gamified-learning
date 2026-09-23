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
    expect(find.text('50 / 100'), findsOneWidget);
    expect(find.text('5 correct'), findsOneWidget);
    expect(find.text('5 wrong'), findsOneWidget);
    expect(find.text('50% accuracy'), findsOneWidget);
    expect(find.text('+35 XP'), findsNWidgets(2));
    expect(find.text('+15 Coins'), findsOneWidget);
    expect(find.text('Level 4'), findsOneWidget);
    expect(find.text('340 / 500 XP'), findsOneWidget);
    expect(find.text('Quiz completion'), findsWidgets);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('+25 XP'), findsOneWidget);
    expect(find.text('+50 pts'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('Speed bonus XP'), findsNothing);
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

    expect(find.text('Quiz points'), findsNWidgets(2));
    expect(
      find.text(
        '+10 points for every correct answer.\n'
        'Wrong and skipped answers give 0 points.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '+10 XP for completing the quiz.\n'
        '+5 XP for every correct answer.\n'
        '+15 XP bonus for a perfect score.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '+5 Coins for completing the quiz.\n'
        '+2 Coins for every correct answer.\n'
        '+10 Coins bonus for a perfect score.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Using a power-up does not reduce your score or XP.'),
      findsOneWidget,
    );
  });

  testWidgets('shows perfect bonuses and separate level-up rewards', (
    tester,
  ) async {
    await _pumpResult(tester, _perfectResult());

    expect(find.text('+75 XP'), findsOneWidget);
    expect(find.text('+35 Coins'), findsOneWidget);
    expect(find.text('Perfect score bonus'), findsNWidgets(2));
    expect(find.text('+15 XP'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('Level up bonus'), findsOneWidget);
    expect(find.text('+50 Coins'), findsOneWidget);
    expect(find.text('+1 Gems'), findsOneWidget);
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
      earnedPoints: 50,
      maxPoints: 100,
      correctCount: 5,
      totalCount: 10,
    ),
    records: const [],
    endedEarly: false,
    streakCount: 0,
    xpAwarded: 35,
    coinsAwarded: 15,
    rewardBreakdown: const QuizRewardBreakdown(
      score: [RewardBreakdownItem(key: 'correct_answer_points', amount: 50)],
      xp: [
        RewardBreakdownItem(key: 'completion_xp', amount: 10),
        RewardBreakdownItem(key: 'correct_answer_xp', amount: 25),
        RewardBreakdownItem(key: 'perfect_bonus_xp', amount: 0),
        RewardBreakdownItem(key: 'speed_bonus_xp', amount: 108),
      ],
      coins: [
        RewardBreakdownItem(key: 'completion_coins', amount: 5),
        RewardBreakdownItem(key: 'correct_answer_coins', amount: 10),
        RewardBreakdownItem(key: 'perfect_bonus_coins', amount: 0),
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

QuizResult _perfectResult() {
  return QuizResult(
    sessionId: 'session-perfect',
    topicId: 'topic-1',
    quizType: QuestionType.mcq,
    score: const Score(
      earnedPoints: 100,
      maxPoints: 100,
      correctCount: 10,
      totalCount: 10,
    ),
    records: const [],
    endedEarly: false,
    streakCount: 0,
    xpAwarded: 75,
    coinsAwarded: 35,
    didLevelUp: true,
    rewardBreakdown: const QuizRewardBreakdown(
      score: [RewardBreakdownItem(key: 'correct_answer_points', amount: 100)],
      xp: [
        RewardBreakdownItem(key: 'completion_xp', amount: 10),
        RewardBreakdownItem(key: 'correct_answer_xp', amount: 50),
        RewardBreakdownItem(key: 'perfect_bonus_xp', amount: 15),
      ],
      coins: [
        RewardBreakdownItem(key: 'completion_coins', amount: 5),
        RewardBreakdownItem(key: 'correct_answer_coins', amount: 20),
        RewardBreakdownItem(key: 'perfect_bonus_coins', amount: 10),
      ],
      levelUp: [
        RewardBreakdownItem(key: 'level_up_bonus_coins', amount: 50),
        RewardBreakdownItem(key: 'level_up_bonus_gems', amount: 1),
      ],
    ),
    timeTaken: const Duration(minutes: 1),
    createdAt: DateTime(2026),
  );
}
