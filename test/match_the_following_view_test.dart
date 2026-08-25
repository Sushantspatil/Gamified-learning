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
  Future<bool> Function(int amount, String reason)? spendCoins,
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
            spendCoinsOverride: spendCoins,
            onSubmit: onSubmit ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _sheetText(String text) {
  return find.descendant(
    of: find.byKey(const Key('power_up_sheet')),
    matching: find.text(text),
  );
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

void main() {
  testWidgets('Match question renders redesigned Match It view', (
    tester,
  ) async {
    await _pumpMatchView(tester);

    expect(find.byKey(const Key('match_it_view')), findsOneWidget);
    expect(find.text('Accountancy'), findsOneWidget);
    expect(find.text('Match each concept'), findsOneWidget);
    expect(find.textContaining('0 of 3'), findsOneWidget);
    expect(find.text('Hint'), findsWidgets);
    expect(find.text('Remove One'), findsWidgets);
    expect(find.text('Reveal Match'), findsWidgets);
  });

  testWidgets('correct pair becomes completed', (tester) async {
    await _pumpMatchView(tester);

    await _selectPair(tester, 'p1', 'p1');

    expect(
      find.descendant(
        of: find.byKey(const Key('match-left-p1')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1 of 3'), findsOneWidget);
  });

  testWidgets('incorrect pair triggers mismatch state and power-up sheet', (
    tester,
  ) async {
    await _pumpMatchView(tester);

    await _selectPair(tester, 'p1', 'p2');

    expect(find.byKey(const Key('match_mismatch_banner')), findsOneWidget);
    expect(find.text('Oops! Mismatch!'), findsOneWidget);
    expect(find.byKey(const Key('power_up_sheet')), findsOneWidget);
  });

  testWidgets('wrong pair does not count as completed', (tester) async {
    await _pumpMatchView(tester);

    await _selectPair(tester, 'p1', 'p2');

    expect(find.textContaining('0 of 3'), findsOneWidget);
  });

  testWidgets('Keep Trying closes sheet without coin debit', (tester) async {
    final spends = <int>[];
    await _pumpMatchView(
      tester,
      spendCoins: (amount, reason) async {
        spends.add(amount);
        return true;
      },
    );

    await _selectPair(tester, 'p1', 'p2');
    await tester.tap(find.textContaining('Keep Trying'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('power_up_sheet')), findsNothing);
    expect(spends, isEmpty);
  });

  testWidgets('Hint usage decreases and shows configured clue', (tester) async {
    await _pumpMatchView(tester);

    await tester.tap(find.byKey(const Key('match-left-p1')));
    await tester.pump();
    await tester.tap(find.text('Hint').first);
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('Hint'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no physical form'), findsOneWidget);
    expect(find.text('0\nLEFT'), findsOneWidget);
  });

  testWidgets('Remove One requires an active concept', (tester) async {
    await _pumpMatchView(tester);

    await tester.tap(find.text('Remove One').first);
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('Remove One'));
    await tester.pump();

    expect(find.text('Select a concept first.'), findsOneWidget);
  });

  testWidgets('Remove One never removes correct answer', (tester) async {
    await _pumpMatchView(tester, spendCoins: (amount, reason) async => true);

    await tester.tap(find.byKey(const Key('match-left-p1')));
    await tester.pump();
    await tester.tap(find.text('Remove One').first);
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('Remove One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use 10 Coins'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('match-right-p1')),
        matching: find.byIcon(Icons.remove_circle),
      ),
      findsNothing,
    );
  });

  testWidgets('Remove One debits 10 coins once', (tester) async {
    final spends = <String>[];
    await _pumpMatchView(
      tester,
      spendCoins: (amount, reason) async {
        spends.add('$amount:$reason');
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('match-left-p1')));
    await tester.pump();
    await tester.tap(find.text('Remove One').first);
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('Remove One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use 10 Coins'));
    await tester.pumpAndSettle();

    expect(spends, ['10:Match It - Remove One']);
  });

  testWidgets('Reveal Match debits 20 coins once and completes correct pair', (
    tester,
  ) async {
    final spends = <String>[];
    await _pumpMatchView(
      tester,
      spendCoins: (amount, reason) async {
        spends.add('$amount:$reason');
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('match-left-p2')));
    await tester.pump();
    await tester.tap(find.text('Reveal Match').first);
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('Reveal Match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use 20 Coins'));
    await tester.pumpAndSettle();

    expect(spends, ['20:Match It - Reveal Match']);
    expect(find.textContaining('1 of 3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('match-left-p2')),
        matching: find.byIcon(Icons.auto_awesome),
      ),
      findsOneWidget,
    );
  });

  testWidgets('insufficient balance prevents paid power-up', (tester) async {
    await _pumpMatchView(
      tester,
      coins: 0,
      spendCoins: (amount, reason) async => false,
    );

    await tester.tap(find.byKey(const Key('match-left-p2')));
    await tester.pump();
    await tester.tap(find.text('Reveal Match').first);
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('Reveal Match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use 20 Coins'));
    await tester.pumpAndSettle();

    expect(find.text('Not enough coins'), findsOneWidget);
    expect(find.textContaining('0 of 3'), findsOneWidget);
  });

  testWidgets('solved pairs cannot be selected again', (tester) async {
    await _pumpMatchView(tester);

    await _selectPair(tester, 'p1', 'p1');
    await tester.tap(find.byKey(const Key('match-left-p1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('match-right-p2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('match_mismatch_banner')), findsNothing);
    expect(find.textContaining('1 of 3'), findsOneWidget);
  });

  testWidgets('quiz answer submits when all pairs are solved', (tester) async {
    MatchTheFollowingAnswer? submitted;
    await _pumpMatchView(
      tester,
      onSubmit: (answer) => submitted = answer as MatchTheFollowingAnswer,
    );

    await _selectPair(tester, 'p1', 'p1');
    await _selectPair(tester, 'p2', 'p2');
    await _selectPair(tester, 'p3', 'p3');
    await tester.ensureVisible(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted?.matchedPairIds, {'p1': 'p1', 'p2': 'p2', 'p3': 'p3'});
  });
}
