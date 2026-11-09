import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/domain/entities/question_answer_record.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_result.dart';
import 'package:skillverse_app/features/quiz/domain/result_answers.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_result_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/result/answer_review_sheet.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/result/answer_strip.dart';

QuestionAnswerRecord _record(int i, {required bool right}) {
  return QuestionAnswerRecord(
    question: McqQuestion(
      id: 'q$i',
      topicId: 't',
      prompt: 'Question number $i?',
      points: 10,
      correctOptionId: 'b',
      options: const [
        QuestionOption(id: 'a', text: 'Sales account'),
        QuestionOption(id: 'b', text: 'Cash account'),
      ],
    ),
    answer: McqAnswer(questionId: 'q$i', selectedOptionId: right ? 'b' : 'a'),
    evaluation: AnswerEvaluation(
      isCorrect: right,
      pointsEarned: right ? 10 : 0,
    ),
  );
}

QuizResult _result(
  List<bool> flags, {
  bool withRecords = true,
  bool endedEarly = false,
  int? total,
}) {
  final correct = flags.where((f) => f).length;
  return QuizResult(
    sessionId: 'answers-${flags.length}-$correct',
    topicId: 'topic-1',
    quizType: QuestionType.mcq,
    score: Score(
      earnedPoints: correct * 10,
      maxPoints: endedEarly ? 0 : flags.length * 10,
      correctCount: correct,
      totalCount: total ?? flags.length,
    ),
    records: withRecords
        ? [
            for (var i = 0; i < flags.length; i++)
              _record(i + 1, right: flags[i]),
          ]
        : const [],
    endedEarly: endedEarly,
    streakCount: 0,
    xpAwarded: 20,
    coinsAwarded: 5,
    rewardBreakdown: const QuizRewardBreakdown(score: [], xp: [], coins: []),
    timeTaken: const Duration(seconds: 30),
    createdAt: DateTime(2026),
  );
}

Future<void> _pumpWidget(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('answerFlags', () {
    test('follows the real answers in order', () {
      final flags = answerFlags(_result([true, false, true]));
      expect(flags, [true, false, true]);
    });

    test('is built from the counts when there are no answers', () {
      final flags = answerFlags(
        _result([true, true, false, false], withRecords: false),
      );
      expect(flags, [true, true, false, false]);
    });

    test('Sudden Death shows the right ones and the one that ended it', () {
      final flags = answerFlags(
        _result(
          [true, true, true],
          withRecords: false,
          endedEarly: true,
          total: 4,
        ),
      );
      expect(flags, [true, true, true, false]);
    });

    test('a Sudden Death run that was never lost has no wrong dot', () {
      final flags = answerFlags(
        _result([true, true], withRecords: false, endedEarly: true),
      );
      expect(flags, [true, true]);
    });

    test('is capped at the limit', () {
      final flags = answerFlags(_result(List.filled(30, true)), limit: 20);
      expect(flags, hasLength(20));
    });
  });

  group('reviewItemsFor', () {
    test('gives the answer text, not the option ids', () {
      final items = reviewItemsFor(_result([true, false]));
      expect(items, hasLength(2));
      expect(items[0].isCorrect, isTrue);
      expect(items[0].yourAnswer, 'Cash account');
      expect(items[1].number, 2);
      expect(items[1].isCorrect, isFalse);
      expect(items[1].yourAnswer, 'Sales account');
      expect(items[1].correctAnswer, 'Cash account');
      expect(items[1].prompt, 'Question number 2?');
    });

    test('is empty when the result has no answers (nothing to review)', () {
      expect(
        reviewItemsFor(_result([true, false], withRecords: false)),
        isEmpty,
      );
    });
  });

  group('AnswerStrip', () {
    testWidgets('draws one dot per answer, ticks and crosses', (tester) async {
      await _pumpWidget(tester, const AnswerStrip(flags: [true, true, false]));
      expect(find.byKey(const Key('dot_0')), findsOneWidget);
      expect(find.byKey(const Key('dot_2')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('2 of 3 right'), findsOneWidget);
      expect(find.byKey(const Key('answer_strip_tap')), findsNothing);
    });

    testWidgets('invites a review when it can be tapped', (tester) async {
      var taps = 0;
      await _pumpWidget(
        tester,
        AnswerStrip(flags: const [true, false], onTap: () => taps++),
      );
      expect(find.text('Review your answers'), findsOneWidget);
      await tester.tap(find.byKey(const Key('answer_strip_tap')));
      expect(taps, 1);
    });

    testWidgets('shows nothing without answers', (tester) async {
      await _pumpWidget(tester, const AnswerStrip(flags: []));
      expect(find.byKey(const Key('answer_strip')), findsNothing);
    });
  });

  group('AnswerReview', () {
    testWidgets('opens on the wrong answers, in red and green', (tester) async {
      final items = reviewItemsFor(_result([true, false, true, false]));
      await _pumpWidget(
        tester,
        AnswerReview(items: items, controller: ScrollController()),
      );
      expect(find.text('2 wrong, 2 right'), findsOneWidget);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);
      expect(find.byKey(const Key('review_item_4')), findsOneWidget);
      expect(find.byKey(const Key('review_item_1')), findsNothing);
      expect(find.text('Your answer'), findsNWidgets(2));
      expect(find.text('Correct answer'), findsNWidgets(2));
      expect(find.byKey(const Key('review_your_answer')), findsNWidgets(2));
      expect(find.byKey(const Key('review_correct_answer')), findsNWidgets(2));
    });

    testWidgets('"All" also lists the right answers', (tester) async {
      final items = reviewItemsFor(_result([true, false]));
      await _pumpWidget(
        tester,
        AnswerReview(items: items, controller: ScrollController()),
      );
      await tester.tap(find.byKey(const Key('review_filter_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);
    });

    testWidgets('a perfect game says so and has no filter', (tester) async {
      final items = reviewItemsFor(_result([true, true]));
      await _pumpWidget(
        tester,
        AnswerReview(items: items, controller: ScrollController()),
      );
      expect(find.text('Every answer was right. Perfect!'), findsOneWidget);
      expect(find.byKey(const Key('review_filter_wrong')), findsNothing);
      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
    });
  });

  group('on the result screen', () {
    testWidgets('tapping the dots opens the review', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: QuizResultView(
              result: _result([true, false, true]),
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('answer_strip_tap')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('answer_review')), findsOneWidget);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);
    });

    testWidgets('a result without answers shows dots but no review', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: QuizResultView(
              result: _result([true, true, false], withRecords: false),
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('answer_strip')), findsOneWidget);
      expect(find.byKey(const Key('answer_strip_tap')), findsNothing);
      expect(find.text('2 of 3 right'), findsOneWidget);
    });
  });
}
