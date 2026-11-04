import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/character3d/presentation/character_3d_view.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/match_the_following_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sudden_death_question_view.dart';

const _match = MatchTheFollowingQuestion(
  id: 'm1',
  topicId: 'mental-maths-easy',
  prompt: 'Mental Maths · Easy: Addition & Subtraction',
  points: 10,
  pairs: [
    MatchPair(id: 'p1', left: '5 - 4', right: '1'),
    MatchPair(id: 'p2', left: '10 - 6', right: '4'),
    MatchPair(id: 'p3', left: '3 + 2', right: '5'),
    MatchPair(id: 'p4', left: '8 + 9', right: '17'),
  ],
);

Future<void> _pumpMatch(
  WidgetTester tester, {
  required Size size,
  int index = 0,
  int total = 10,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: MatchTheFollowingView(
            question: _match,
            coinBalanceOverride: 2844,
            currentIndex: index,
            totalQuestions: total,
            onSubmit: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Match It', () {
    testWidgets('the button says Next on every board but the last', (
      tester,
    ) async {
      await _pumpMatch(tester, size: const Size(412, 915), index: 3);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('the last board asks for Submit', (tester) async {
      await _pumpMatch(tester, size: const Size(412, 915), index: 9);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('the character stands between the prompt and the pairs', (
      tester,
    ) async {
      await _pumpMatch(tester, size: const Size(412, 915));
      final character = find.byType(Character3dView);
      expect(character, findsOneWidget);
      final prompt = tester.getRect(
        find.text('Mental Maths · Easy: Addition & Subtraction'),
      );
      final firstPair = tester.getRect(find.byKey(const Key('match-left-p1')));
      final box = tester.getRect(character);
      expect(box.top, greaterThanOrEqualTo(prompt.bottom));
      expect(box.bottom, lessThanOrEqualTo(firstPair.top));
      // and the button sits at the bottom of the screen
      final button = tester.getRect(find.byKey(const Key('match_next_button')));
      expect(button.bottom, greaterThan(915 * 0.85));
      expect(tester.takeException(), isNull);
    });

    testWidgets('there is no running "x of y matched" line', (tester) async {
      await _pumpMatch(tester, size: const Size(412, 915));
      expect(find.textContaining(' matched'), findsNothing);
      expect(find.textContaining('0 of 4'), findsNothing);
    });

    testWidgets('cards are compact for short text and grow for long text', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const mixed = MatchTheFollowingQuestion(
        id: 'm2',
        topicId: 'accounting',
        prompt: 'Match',
        points: 10,
        pairs: [
          MatchPair(id: 's', left: '1 + 3', right: '4'),
          MatchPair(
            id: 'l',
            left:
                'The revenue realization and matching principle under the standard framework',
            right: 'Accrual accounting',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: MatchTheFollowingView(
                question: mixed,
                coinBalanceOverride: 10,
                totalQuestions: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final short = tester.getSize(find.byKey(const Key('match-left-s')));
      final long = tester.getSize(find.byKey(const Key('match-left-l')));
      expect(short.height, lessThan(70)); // compact (was a fixed 82)
      expect(long.height, greaterThan(short.height + 20)); // grew to fit
      // the long label is fully readable: no ellipsis forced by a fixed height
      expect(tester.takeException(), isNull);
    });

    testWidgets('the character takes the room that is left, within limits', (
      tester,
    ) async {
      final sizes = <double>[];
      for (final height in [700.0, 760.0, 820.0]) {
        await _pumpMatch(tester, size: Size(412, height));
        final found = find.byType(Character3dView);
        sizes.add(found.evaluate().isEmpty ? 0 : tester.getSize(found).height);
      }
      // more screen, more character (never beyond the limits), and a screen that
      // is too short for it simply has none
      for (final h in sizes.where((h) => h > 0)) {
        expect(h, inInclusiveRange(96, 240));
      }
      expect(sizes[1], greaterThanOrEqualTo(sizes[0]));
      expect(sizes[2], greaterThanOrEqualTo(sizes[1]));
      expect(sizes[2], greaterThan(sizes[0]));
    });

    testWidgets('a short screen leaves the character out and just scrolls', (
      tester,
    ) async {
      await _pumpMatch(tester, size: const Size(360, 560));
      expect(find.byType(Character3dView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Sudden Death', () {
    const question = SuddenDeathQuestion(
      id: 'sd-1',
      prompt: '9 + 2 = ?',
      points: 10,
      options: [
        QuestionOption(id: 'a', text: '12'),
        QuestionOption(id: 'b', text: '11'),
      ],
      correctOptionId: 'b',
      topicId: 'mental-maths',
    );

    Future<void> pump(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SuddenDeathQuestionView(
                question: question,
                currentIndex: 0,
                totalQuestions: 10,
                currentStreak: 0,
                bestStreak: 0,
                energy: 0,
                coins: 2799,
                onExit: () {},
                isPreviewMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the 3D character replaces the skull mascot card', (
      tester,
    ) async {
      await pump(tester, const Size(412, 915));
      expect(find.byType(Character3dView), findsOneWidget);
      expect(find.text("Don't lose the streak!"), findsNothing);
      // it stands below the question card
      final card = tester.getRect(find.text('9 + 2 = ?'));
      expect(
        tester.getRect(find.byType(Character3dView)).top,
        greaterThan(card.bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the character is as large as the free space allows', (
      tester,
    ) async {
      final sizes = <double>[];
      for (final height in [760.0, 850.0, 960.0]) {
        await pump(tester, Size(412, height));
        final found = find.byType(Character3dView);
        sizes.add(found.evaluate().isEmpty ? 0 : tester.getSize(found).height);
      }
      for (final h in sizes.where((h) => h > 0)) {
        expect(h, inInclusiveRange(96, 240));
      }
      expect(sizes[2], greaterThan(sizes[0]));
      expect(sizes[1], greaterThanOrEqualTo(sizes[0]));
    });

    testWidgets('a short screen simply has no character', (tester) async {
      await pump(tester, const Size(360, 600));
      expect(find.byType(Character3dView), findsNothing);
      expect(find.text("Don't lose the streak!"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
