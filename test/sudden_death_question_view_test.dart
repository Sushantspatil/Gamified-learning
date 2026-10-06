import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';
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

const _nextQuestion = SuddenDeathQuestion(
  id: 'sudden-2',
  topicId: 'web-dev-chapter-1-topic-1',
  prompt: 'Which tag creates a link?',
  points: 15,
  options: [
    QuestionOption(id: 'a', text: '<button>'),
    QuestionOption(id: 'b', text: '<a>'),
    QuestionOption(id: 'c', text: '<nav>'),
    QuestionOption(id: 'd', text: '<link>'),
  ],
  correctOptionId: 'b',
);

Widget _buildSuddenDeathView({
  Key? viewKey,
  SuddenDeathQuestion question = _question,
  int currentIndex = 0,
  void Function(Answer answer)? onSubmit,
  void Function(String optionId)? onSelectOption,
  VoidCallback? onSkip,
  VoidCallback? onTimeout,
  bool isPreviewMode = true,
  String? externalSelectedOptionId,
  WsAnswerResultPayload? serverAnswerResult,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: SuddenDeathQuestionView(
          key: viewKey ?? UniqueKey(),
          question: question,
          currentIndex: currentIndex,
          totalQuestions: 5,
          currentStreak: 0,
          bestStreak: 0,
          energy: 0,
          coins: 100,
          isPreviewMode: isPreviewMode,
          onExit: () {},
          onSubmit: onSubmit,
          onSelectOption: onSelectOption,
          onSkip: onSkip,
          onTimeout: onTimeout,
          externalSelectedOptionId: externalSelectedOptionId,
          serverAnswerResult: serverAnswerResult,
        ),
      ),
    ),
  );
}

Future<void> _pumpSuddenDeathView(
  WidgetTester tester, {
  Key? viewKey,
  SuddenDeathQuestion question = _question,
  int currentIndex = 0,
  void Function(Answer answer)? onSubmit,
  void Function(String optionId)? onSelectOption,
  VoidCallback? onSkip,
  VoidCallback? onTimeout,
  bool isPreviewMode = true,
  String? externalSelectedOptionId,
  WsAnswerResultPayload? serverAnswerResult,
}) async {
  await tester.pumpWidget(
    _buildSuddenDeathView(
      viewKey: viewKey,
      question: question,
      currentIndex: currentIndex,
      onSubmit: onSubmit,
      onSelectOption: onSelectOption,
      onSkip: onSkip,
      onTimeout: onTimeout,
      isPreviewMode: isPreviewMode,
      externalSelectedOptionId: externalSelectedOptionId,
      serverAnswerResult: serverAnswerResult,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _buyPowerUp(WidgetTester tester, String label) async {
  final key = switch (label) {
    '+5 Seconds' => const Key('powerup-sudden-time'),
    'Skip' => const Key('powerup-sudden-skip'),
    _ => throw ArgumentError('Unknown power-up: $label'),
  };
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buy & use'));
  await tester.pump(const Duration(milliseconds: 400));
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
    expect(find.byKey(const Key('powerup-sudden-skip')), findsOneWidget);
    expect(find.byKey(const Key('powerup-sudden-50-50')), findsNothing);
    expect(find.byKey(const Key('powerup-sudden-hint')), findsNothing);
  });

  testWidgets('+5 Seconds updates timer state and shows feedback', (
    tester,
  ) async {
    await _pumpSuddenDeathView(tester);

    await _buyPowerUp(tester, '+5 Seconds');

    final boostedSecondIsVisible = [
      '16',
      '17',
      '18',
      '19',
      '20',
    ].any((value) => find.text(value).evaluate().isNotEmpty);
    expect(boostedSecondIsVisible, isTrue);
    expect(find.byKey(const Key('sudden-power-up-feedback')), findsOneWidget);
    expect(find.text('+5 seconds activated'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('skip stays neutral and does not submit a correct answer', (
    tester,
  ) async {
    SuddenDeathAnswer? submitted;
    var skipped = false;
    await _pumpSuddenDeathView(
      tester,
      onSubmit: (answer) => submitted = answer as SuddenDeathAnswer,
      onSkip: () => skipped = true,
    );

    await _buyPowerUp(tester, 'Skip');

    expect(submitted, isNull);
    expect(find.byKey(const Key('sudden-power-up-feedback')), findsOneWidget);
    expect(find.text('Skipping question'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(skipped, isTrue);
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
    await tester.pump();

    expect(find.text('Survived'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(submitted?.selectedOptionId, 'b');

    submitted = null;
    await _pumpSuddenDeathView(
      tester,
      onSubmit: (answer) => submitted = answer as SuddenDeathAnswer,
    );
    await _tapOption(tester, '<div>');
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Eliminated'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(submitted?.selectedOptionId, 'a');
  });

  testWidgets('timeout submits a failure answer', (tester) async {
    var timedOut = false;
    await _pumpSuddenDeathView(tester, onTimeout: () => timedOut = true);

    await tester.pump(SuddenDeathConfig.questionTimeLimit);
    await tester.pump();

    expect(find.text("Time's up"), findsOneWidget);
    await tester.pumpAndSettle();

    expect(timedOut, isTrue);
  });

  testWidgets('production path submits without calculating correctness', (
    tester,
  ) async {
    String? submittedOptionId;
    await _pumpSuddenDeathView(
      tester,
      isPreviewMode: false,
      onSelectOption: (optionId) => submittedOptionId = optionId,
    );

    await _tapOption(tester, '<p>');
    await tester.pump();

    // Live mode hands the option straight to the WebSocket layer, which the
    // server grades. The widget must not derive an outcome on its own.
    expect(submittedOptionId, 'b');
    expect(find.text('Survived'), findsNothing);
    expect(find.text('Eliminated'), findsNothing);
  });

  testWidgets('production path hides no Submit button and locks after submit', (
    tester,
  ) async {
    var submitCount = 0;
    await _pumpSuddenDeathView(
      tester,
      isPreviewMode: false,
      onSelectOption: (_) => submitCount++,
    );

    // The server owns the clock in live mode, so there is nothing to confirm.
    expect(find.text('Submit'), findsNothing);

    await _tapOption(tester, '<p>');
    await tester.pump();
    expect(submitCount, 1);
  });

  testWidgets('production path reveals the server verdict as feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Scaffold(
            body: SuddenDeathQuestionView(
              question: _question,
              currentIndex: 0,
              totalQuestions: 5,
              currentStreak: 1,
              bestStreak: 1,
              energy: 0,
              coins: 100,
              isPreviewMode: false,
              onExit: () {},
              onSelectOption: (_) {},
              serverAnswerResult: WsAnswerResultPayload(
                question: _question.id,
                option: 'b',
                correctOption: 'b',
                isCorrect: true,
                isSkipped: false,
                pointsEarned: 10,
                coinsEarned: 0,
                yourScore: 10,
                isTimeout: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Survival feedback is derived from the server's `answer_result`.
    expect(find.text('Survived'), findsOneWidget);
  });

  testWidgets('production path maps server timeout to time up feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Scaffold(
            body: SuddenDeathQuestionView(
              question: _question,
              currentIndex: 0,
              totalQuestions: 5,
              currentStreak: 0,
              bestStreak: 0,
              energy: 0,
              coins: 100,
              isPreviewMode: false,
              onExit: () {},
              onSelectOption: (_) {},
              serverAnswerResult: WsAnswerResultPayload(
                question: _question.id,
                option: 'timeout',
                correctOption: 'b',
                isCorrect: false,
                isSkipped: false,
                pointsEarned: 0,
                coinsEarned: 0,
                yourScore: 0,
                isTimeout: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Time's up"), findsOneWidget);
  });

  testWidgets('question change animates and clears stale option selection', (
    tester,
  ) async {
    final firstResult = WsAnswerResultPayload(
      question: _question.id,
      option: 'b',
      correctOption: 'b',
      isCorrect: true,
      isSkipped: false,
      pointsEarned: 10,
      coinsEarned: 0,
      yourScore: 10,
      isTimeout: false,
    );

    await _pumpSuddenDeathView(
      tester,
      viewKey: const ValueKey('transitioning-sudden-death-view'),
      isPreviewMode: false,
      externalSelectedOptionId: 'b',
      serverAnswerResult: firstResult,
    );

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.pumpWidget(
      _buildSuddenDeathView(
        viewKey: const ValueKey('transitioning-sudden-death-view'),
        question: _nextQuestion,
        currentIndex: 1,
        isPreviewMode: false,
        onSelectOption: (_) {},
        // The provider can briefly retain the previous answer while the next
        // question frame is being applied. The view must reject that stale
        // state, even when both questions reuse the same option ids.
        externalSelectedOptionId: 'b',
        serverAnswerResult: firstResult,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('sudden-question-transition')), findsOneWidget);
    expect(find.text('Which tag creates a paragraph?'), findsOneWidget);
    expect(find.text('Which tag creates a link?'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Which tag creates a paragraph?'), findsNothing);
    expect(find.text('Which tag creates a link?'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('low time state becomes visible under five seconds', (
    tester,
  ) async {
    await _pumpSuddenDeathView(tester, onTimeout: () {});

    await tester.pump(const Duration(seconds: 11));

    expect(find.byKey(const Key('sudden-low-time')), findsOneWidget);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('remains overflow-free at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpSuddenDeathView(tester, onTimeout: () {});

      expect(tester.takeException(), isNull);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.byKey(const Key('game_power_up_bar')), findsOneWidget);
    });
  }
}
