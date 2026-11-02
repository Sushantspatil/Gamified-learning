import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_question_view.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';
import 'package:skillverse_app/features/rewards/data/rewards_store.dart';
import 'package:skillverse_app/features/rewards/domain/rewards_models.dart';

const _options4 = [
  QuestionOption(id: 'a', text: 'Revenue'),
  QuestionOption(id: 'b', text: 'Inventory'),
  QuestionOption(id: 'c', text: 'Expense'),
  QuestionOption(id: 'd', text: 'Capital'),
];

McqQuestion _question({
  String? hint = 'Think about what a business owns.',
  List<QuestionOption> options = _options4,
}) => McqQuestion(
  id: 'q1',
  topicId: 't',
  prompt: 'Which is an asset?',
  points: 10,
  options: options,
  correctOptionId: 'b',
  hint: hint,
);

ProviderContainer? _container;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  McqQuestion question, {
  Map<String, int> tokens = const {},
  List<Answer>? submitted,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  await storage.setString(
    RewardsStore.key,
    jsonEncode({'coins': 500, 'powerUps': tokens}),
  );
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
    ],
  );
  _container = container;

  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: McqQuestionView(
            question: question,
            currentIndex: 0,
            totalQuestions: 3,
            currentStreak: 0,
            coins: 0,
            energy: 0,
            onExit: () {},
            onSubmit: (a) => submitted?.add(a),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

int _count(ProviderContainer c, PowerUpType t) =>
    c.read(rewardsProvider).powerUpCount(t);

/// testWidgets that also unmounts the screen, so the character timers end.
void _test(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    _container?.dispose(); // ends the character timers
    _container = null;
    await tester.pump();
  });
}

void main() {
  _test('no token buttons without tokens', (tester) async {
    await _pump(tester, _question());
    expect(find.byKey(const Key('use_hint_token')), findsNothing);
    expect(find.byKey(const Key('use_fifty_fifty_token')), findsNothing);
  });

  _test('Hint Token shows the question hint, then is consumed', (tester) async {
    final c = await _pump(tester, _question(), tokens: {'hint': 2});
    expect(find.text('Think about what a business owns.'), findsNothing);

    await tester.tap(find.byKey(const Key('use_hint_token')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Think about what a business owns.'), findsOneWidget);
    expect(_count(c, PowerUpType.hint), 1);
    // The answer is never revealed and the token cannot be reused here.
    expect(find.textContaining('Correct'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('use_hint_token')))
          .onPressed,
      isNull,
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  _test('Hint Token is unavailable when the question has no hint', (
    tester,
  ) async {
    final c = await _pump(tester, _question(hint: null), tokens: {'hint': 1});

    expect(find.text('This question has no hint.'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('use_hint_token')),
    );
    expect(button.onPressed, isNull);
    expect(_count(c, PowerUpType.hint), 1);
    // No invented hint text appears either.
    expect(find.textContaining('eliminate choices'), findsNothing);
  });

  _test('50/50 Token hides exactly two wrong options, not the right one', (
    tester,
  ) async {
    final c = await _pump(tester, _question(), tokens: {'fiftyFifty': 2});

    await tester.tap(find.byKey(const Key('use_fifty_fifty_token')));
    await tester.pump(const Duration(milliseconds: 400));

    final visible = [
      'Revenue',
      'Inventory',
      'Expense',
      'Capital',
    ].where((t) => find.text(t).evaluate().isNotEmpty).toList();
    expect(visible.length, 2);
    expect(visible, contains('Inventory')); // the correct option stays
    expect(_count(c, PowerUpType.fiftyFifty), 1);

    // Only once per question: the second token is not spent.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('use_fifty_fifty_token')),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  _test('50/50 Token is unavailable with fewer than four options', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      _question(options: _options4.take(2).toList()),
      tokens: {'fiftyFifty': 1},
    );

    expect(
      find.text('50/50 is not available for this question.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('use_fifty_fifty_token')),
          )
          .onPressed,
      isNull,
    );
    expect(_count(c, PowerUpType.fiftyFifty), 1);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
  });

  _test('tokens cannot be used after the answer is submitted', (tester) async {
    final submitted = <Answer>[];
    final c = await _pump(
      tester,
      _question(),
      tokens: {'hint': 1, 'fiftyFifty': 1},
      submitted: submitted,
    );

    await tester.tap(find.text('Capital'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 50));

    for (final key in ['use_hint_token', 'use_fifty_fifty_token']) {
      expect(
        tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
        isNull,
      );
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(_count(c, PowerUpType.hint), 1);
    expect(_count(c, PowerUpType.fiftyFifty), 1);
    expect(submitted.length, 1);
  });
}
