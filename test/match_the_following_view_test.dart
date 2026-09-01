import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/match_the_following_view.dart';

const _question = MatchTheFollowingQuestion(
  id: 'match-1',
  topicId: 'accountancy-chapter-1-topic-1',
  prompt: 'Match each concept',
  points: 15,
  pairs: [
    MatchPair(
      id: 'p1',
      left: 'Goodwill',
      right: 'Intangible Asset',
      hint: 'Think about something valuable that has no physical form.',
    ),
    MatchPair(
      id: 'p2',
      left: 'Inventory',
      right: 'Current Asset',
      hint: 'This item is usually sold or used within the current cycle.',
    ),
    MatchPair(
      id: 'p3',
      left: 'Debenture',
      right: 'Long-term Liability',
      hint: 'This is a borrowed source of funds repaid over time.',
    ),
  ],
);

Future<void> _pumpMatchView(
  WidgetTester tester, {
  void Function(Answer answer)? onSubmit,
  int coins = 60,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storageService = await LocalStorageService.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storageService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          body: MatchTheFollowingView(
            question: _question,
            coinBalanceOverride: coins,
            onSubmit: onSubmit ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectPair(
  WidgetTester tester,
  String leftId,
  String rightId,
) async {
  await tester.ensureVisible(find.byKey(Key('match-left-$leftId')));
  await tester.tap(find.byKey(Key('match-left-$leftId')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(Key('match-right-$rightId')));
  await tester.tap(find.byKey(Key('match-right-$rightId')));
  await tester.pumpAndSettle();
}

Future<void> _submitForAnalysis(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Submit'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Submit'));
  await tester.pumpAndSettle();
}

Future<void> _continueFromAnalysis(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pump();
}

void main() {
  testWidgets('opens without correctness or match lifelines', (tester) async {
    await _pumpMatchView(tester);

    expect(find.byKey(const Key('match_it_view')), findsOneWidget);
    expect(find.text('Accountancy'), findsOneWidget);
    expect(find.text('Match each concept'), findsOneWidget);
    expect(find.textContaining('0 of 3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.byKey(const Key('power_up_sheet')), findsNothing);
    expect(find.text('Remove One'), findsNothing);
    expect(find.text('Reveal Match'), findsNothing);
  });

  testWidgets('wrong pair is only a neutral selection before submit', (
    tester,
  ) async {
    await _pumpMatchView(tester);

    await _selectPair(tester, 'p1', 'p2');

    expect(find.textContaining('1 of 3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.byKey(const Key('match_analysis_summary')), findsNothing);
    expect(find.byKey(const Key('power_up_sheet')), findsNothing);
  });

  testWidgets('student can change a selected pair before submit', (
    tester,
  ) async {
    MatchTheFollowingAnswer? submitted;
    await _pumpMatchView(
      tester,
      onSubmit: (answer) => submitted = answer as MatchTheFollowingAnswer,
    );

    await _selectPair(tester, 'p1', 'p2');
    await _selectPair(tester, 'p1', 'p1');
    await _selectPair(tester, 'p2', 'p2');
    await _selectPair(tester, 'p3', 'p3');
    await _submitForAnalysis(tester);
    await _continueFromAnalysis(tester);

    expect(submitted?.matchedPairIds, {'p1': 'p1', 'p2': 'p2', 'p3': 'p3'});
  });

  testWidgets('submit is disabled until all pairs are selected', (
    tester,
  ) async {
    MatchTheFollowingAnswer? submitted;
    await _pumpMatchView(
      tester,
      onSubmit: (answer) => submitted = answer as MatchTheFollowingAnswer,
    );

    await _selectPair(tester, 'p1', 'p1');
    await tester.ensureVisible(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('match_analysis_summary')), findsNothing);
    expect(submitted, isNull);
  });

  testWidgets('submit validates all pairs and shows correct answers', (
    tester,
  ) async {
    await _pumpMatchView(tester);

    await _selectPair(tester, 'p1', 'p2');
    await _selectPair(tester, 'p2', 'p1');
    await _selectPair(tester, 'p3', 'p3');
    await _submitForAnalysis(tester);

    expect(find.byKey(const Key('match_analysis_summary')), findsOneWidget);
    expect(find.text('Correct answers'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    expect(find.byIcon(Icons.cancel), findsWidgets);
    expect(find.text('Selected: Current Asset'), findsOneWidget);
    expect(find.text('Correct: Intangible Asset'), findsOneWidget);
  });

  testWidgets('submitted board is locked until continuing', (tester) async {
    MatchTheFollowingAnswer? submitted;
    await _pumpMatchView(
      tester,
      onSubmit: (answer) => submitted = answer as MatchTheFollowingAnswer,
    );

    await _selectPair(tester, 'p1', 'p2');
    await _selectPair(tester, 'p2', 'p1');
    await _selectPair(tester, 'p3', 'p3');
    await _submitForAnalysis(tester);
    await _selectPair(tester, 'p1', 'p1');
    await _continueFromAnalysis(tester);

    expect(submitted?.matchedPairIds, {'p1': 'p2', 'p2': 'p1', 'p3': 'p3'});
  });
}
