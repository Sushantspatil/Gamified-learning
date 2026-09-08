import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sort_it_right_view.dart';
import 'package:skillverse_app/features/wallet/domain/entities/currency_type.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

const question = SortItRightQuestion(
  id: 'sort',
  topicId: 'topic',
  prompt: 'Classify each account',
  points: 10,
  leftCategory: 'Real',
  rightCategory: 'Personal',
  itemsInOrder: [
    'Cash A/C',
    'Land A/C',
    'Ravi A/C',
    'Machinery A/C',
    'Meena A/C',
  ],
  correctSides: [
    SortSide.left,
    SortSide.left,
    SortSide.right,
    SortSide.left,
    SortSide.right,
  ],
  hint: 'Think about assets and people.',
);

class _SignedInAuth extends AuthController {
  @override
  Future<AppUser?> build() async => const AppUser(
    id: 'sort-user',
    email: 'test@example.com',
    displayName: 'Tester',
  );
}

Future<ProviderContainer> pumpSort(
  WidgetTester tester, {
  SortItRightQuestion data = question,
  Size size = const Size(393, 852),
  double textScale = 1,
  int coins = 100,
  bool reducedMotion = false,
  Duration fallDuration = sortFallDuration,
  SortTimeoutBehavior timeoutBehavior = SortTimeoutBehavior.miss,
  void Function(Answer)? onSubmit,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [authControllerProvider.overrideWith(_SignedInAuth.new)],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() async {
    await container.read(authControllerProvider.future);
    await container.read(walletControllerProvider.future);
    if (coins > 0) {
      await container
          .read(walletControllerProvider.notifier)
          .credit(
            currency: CurrencyType.coins,
            amount: coins,
            reason: 'Test balance',
          );
    }
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SortItRightView(
              question: data,
              fallDuration: fallDuration,
              timeoutBehavior: timeoutBehavior,
              currentIndex: 0,
              totalQuestions: 1,
              currentStreak: 0,
              coins: coins,
              energy: 0,
              onExit: () {},
              onSubmit: onSubmit ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> start(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Start sorting'));
  await tester.tap(find.text('Start sorting'));
  await tester.pump();
}

Future<void> finishExit(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(sortExitDuration);
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> nextItem(WidgetTester tester) async {
  await tester.pump(sortFeedbackDuration);
  await tester.pump();
}

Future<void> tapSide(WidgetTester tester, String side) async {
  await tester.tap(find.byKey(ValueKey('sort-bucket-$side')));
  await finishExit(tester);
  await nextItem(tester);
}

Future<void> buy(WidgetTester tester, String action) async {
  await tester.ensureVisible(find.byKey(Key('powerup-sort-$action')));
  await tester.tap(find.byKey(Key('powerup-sort-$action')));
  await tester.pumpAndSettle(); // The fall is paused while the sheet is open.
  await tester.tap(find.text('Buy & use'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

Future<void> continueSorting(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue sorting'));
  await tester.tap(find.text('Continue sorting'));
  await tester.pump();
}

final card = find.byKey(const Key('sort-active-card'));
final stage = find.byKey(const Key('sort-playfield'));
final left = find.byKey(const ValueKey('sort-bucket-debit'));
final right = find.byKey(const ValueKey('sort-bucket-credit'));

void main() {
  testWidgets(
    'item starts at top and falls continuously without moving categories',
    (tester) async {
      await pumpSort(tester);
      expect(find.text('5 items. Two groups.'), findsOneWidget);
      await start(tester);
      expect(find.text('Cash A/C'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      final startY = tester.getTopLeft(card).dy;
      final categoryBounds = tester.getRect(left);
      final categoryWidget = tester.widget<OutlinedButton>(
        find.descendant(of: left, matching: find.byType(OutlinedButton)),
      );
      expect(startY, closeTo(tester.getTopLeft(stage).dy, 1));
      await tester.pump(const Duration(seconds: 1));
      final firstY = tester.getTopLeft(card).dy;
      await tester.pump(const Duration(seconds: 1));
      final secondY = tester.getTopLeft(card).dy;
      expect(firstY, greaterThan(startY));
      expect(secondY - firstY, closeTo(firstY - startY, 1));
      expect(tester.getRect(left), categoryBounds);
      expect(
        identical(
          categoryWidget,
          tester.widget<OutlinedButton>(
            find.descendant(of: left, matching: find.byType(OutlinedButton)),
          ),
        ),
        isTrue,
      );
      expect(tester.getBottomLeft(card).dy, lessThan(categoryBounds.top));
    },
  );

  for (final side in ['debit', 'credit']) {
    testWidgets('swipe $side while falling commits toward that category', (
      tester,
    ) async {
      await pumpSort(tester);
      await start(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final original = tester.getCenter(card);
      final drag = await tester.startGesture(original);
      final sign = side == 'debit' ? -1.0 : 1.0;
      await drag.moveBy(Offset(sign * 35, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getCenter(card).dy, greaterThan(original.dy));
      expect((tester.getCenter(card).dx - original.dx) * sign, greaterThan(0));
      final target = side == 'debit' ? left : right;
      expect(
        tester
            .widget<Semantics>(
              find
                  .descendant(of: target, matching: find.byType(Semantics))
                  .first,
            )
            .properties
            .selected,
        isTrue,
      );
      await drag.moveBy(Offset(sign * 90, 0));
      await tester.pump();
      final distance =
          (tester.getCenter(card) - tester.getCenter(target)).distance;
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        (tester.getCenter(card) - tester.getCenter(target)).distance,
        lessThan(distance),
      );
      await drag.up();
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(milliseconds: 16));
      expect(card, findsNothing);
      expect(find.text(side == 'debit' ? 'Correct' : 'Wrong'), findsOneWidget);
      await nextItem(tester);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        closeTo(tester.getTopLeft(stage).dy, 1),
      );
    });
  }

  testWidgets('short drag returns horizontally while the fall continues', (
    tester,
  ) async {
    await pumpSort(tester);
    await start(tester);
    final original = tester.getCenter(card);
    final drag = await tester.startGesture(original);
    await drag.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await drag.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getCenter(card).dx, closeTo(original.dx, 1));
    expect(tester.getCenter(card).dy, greaterThan(original.dy));
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('tap both categories plays five items and submits exactly once', (
    tester,
  ) async {
    final answers = <SortAnswer>[];
    await pumpSort(
      tester,
      onSubmit: (answer) => answers.add(answer as SortAnswer),
    );
    await start(tester);
    await tapSide(tester, 'debit');
    expect(find.text('1 correct · 0 wrong'), findsOneWidget);
    await tapSide(tester, 'credit');
    expect(find.text('1 correct · 1 wrong'), findsOneWidget);
    await tapSide(tester, 'credit');
    await tapSide(tester, 'debit');
    await tapSide(tester, 'credit');
    expect(answers.single.selectedSides, [
      SortSide.left,
      SortSide.right,
      SortSide.right,
      SortSide.left,
      SortSide.right,
    ]);
    await tester.pump(const Duration(seconds: 10));
    expect(answers, hasLength(1));
    expect(card, findsNothing);
  });

  testWidgets(
    'five timeouts record five misses with feedback before each spawn',
    (tester) async {
      final answers = <SortAnswer>[];
      await pumpSort(
        tester,
        onSubmit: (answer) => answers.add(answer as SortAnswer),
      );
      await start(tester);
      for (var i = 1; i <= 5; i++) {
        expect(find.text('$i / 5'), findsOneWidget);
        await tester.pump(sortFallDuration);
        await tester.pump(const Duration(milliseconds: 16));
        await finishExit(tester);
        expect(find.text('Missed'), findsOneWidget);
        expect(find.textContaining('Correct answer:'), findsOneWidget);
        expect(card, findsNothing);
        await nextItem(tester);
      }
      expect(answers.single.selectedSides, [null, null, null, null, null]);
    },
  );

  testWidgets('duration and wait-at-boundary behavior are configurable', (
    tester,
  ) async {
    await pumpSort(
      tester,
      fallDuration: const Duration(seconds: 2),
      timeoutBehavior: SortTimeoutBehavior.waitForAnswer,
    );
    await start(tester);
    final top = tester.getTopLeft(card).dy;
    await tester.pump(const Duration(seconds: 1));
    final middle = tester.getTopLeft(card).dy;
    await tester.pump(const Duration(seconds: 1));
    final bottom = tester.getTopLeft(card).dy;
    expect(middle - top, closeTo((bottom - top) / 2, 1));
    expect(
      tester.getBottomLeft(card).dy,
      closeTo(tester.getBottomLeft(stage).dy, 1),
    );
    await tester.pump(const Duration(seconds: 8));
    expect(tester.getTopLeft(card).dy, bottom);
    expect(find.text('Missed'), findsNothing);
    await tapSide(tester, 'debit');
    expect(find.text('1 correct · 0 wrong'), findsOneWidget);
  });

  testWidgets('a last-moment tap stops timeout and cannot double-score', (
    tester,
  ) async {
    final answers = <SortAnswer>[];
    await pumpSort(
      tester,
      onSubmit: (answer) => answers.add(answer as SortAnswer),
    );
    await start(tester);
    await tester.pump(const Duration(milliseconds: 3990));
    await tester.tap(left);
    await tester.tap(right);
    await finishExit(tester);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Missed'), findsNothing);
    await nextItem(tester);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('1 correct · 0 wrong'), findsOneWidget);
  });

  testWidgets(
    'quick-buy pauses the whole sheet and cancellation resumes remaining fall',
    (tester) async {
      final container = await pumpSort(tester);
      await start(tester);
      await tester.pump(const Duration(seconds: 1));
      final position = tester.getCenter(card);
      await tester.tap(find.byKey(const Key('powerup-sort-hint')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 8));
      expect(tester.getCenter(card), position);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('1 / 5'), findsOneWidget);
      expect(tester.getCenter(card).dy, greaterThan(position.dy));
      expect(container.read(walletControllerProvider).requireValue.coins, 100);
    },
  );

  testWidgets(
    'Hint and Reveal pause until Continue and retain their costs and scoring',
    (tester) async {
      final container = await pumpSort(tester);
      await start(tester);
      await tester.pump(const Duration(seconds: 1));
      await buy(tester, 'hint');
      expect(find.text(question.hint!), findsOneWidget);
      final position = tester.getCenter(card);
      await tester.pump(const Duration(seconds: 8));
      expect(tester.getCenter(card), position);
      expect(find.text('1 / 5'), findsOneWidget);
      await continueSorting(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getCenter(card).dy, greaterThan(position.dy));
      await buy(tester, 'reveal');
      expect(find.text('Correct group: Real'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('1 / 5'), findsOneWidget);
      expect(container.read(walletControllerProvider).requireValue.coins, 65);
      await continueSorting(tester);
      await tapSide(tester, 'debit');
      expect(find.text('1 correct · 0 wrong'), findsOneWidget);
    },
  );

  testWidgets(
    'Undo restores missed and correct items at the top without duplicate history',
    (tester) async {
      final container = await pumpSort(tester);
      await start(tester);
      await tapSide(tester, 'debit');
      await tester.pump(sortFallDuration);
      await tester.pump(const Duration(milliseconds: 16));
      await finishExit(tester);
      await nextItem(tester);
      await buy(tester, 'undo');
      expect(find.text('Land A/C'), findsOneWidget);
      expect(find.text('1 correct · 0 wrong'), findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        closeTo(tester.getTopLeft(stage).dy, 1),
      );
      await buy(tester, 'undo');
      expect(find.text('Cash A/C'), findsOneWidget);
      expect(find.text('0 correct · 0 wrong'), findsOneWidget);
      expect(container.read(walletControllerProvider).requireValue.coins, 80);
      await tapSide(tester, 'debit');
      expect(find.text('1 correct · 0 wrong'), findsOneWidget);
    },
  );

  testWidgets('insufficient balance resumes without applying help', (
    tester,
  ) async {
    final container = await pumpSort(tester, coins: 0);
    await start(tester);
    await buy(tester, 'hint');
    expect(find.text(question.hint!), findsNothing);
    final position = tester.getCenter(card);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getCenter(card).dy, greaterThan(position.dy));
    expect(container.read(walletControllerProvider).requireValue.coins, 0);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets(
      'portrait $size keeps fall inside its stage and 16px category margins',
      (tester) async {
        await pumpSort(tester, size: size);
        await start(tester);
        expect(tester.getRect(left).left, 16);
        expect(tester.getRect(right).right, size.width - 16);
        expect(
          tester.getTopLeft(card).dy,
          closeTo(tester.getTopLeft(stage).dy, 1),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(
          tester.getBottomLeft(card).dy,
          lessThanOrEqualTo(tester.getTopLeft(left).dy),
        );
        await buy(tester, 'hint');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'large text and reduced motion remain playable without an invisible timeout',
    (tester) async {
      const long = SortItRightQuestion(
        id: 'long',
        topicId: 't',
        prompt: 'Sort',
        points: 10,
        leftCategory: 'Long real account category',
        rightCategory: 'Long personal account category',
        itemsInOrder: ['An account with a long descriptive name', 'Second'],
        correctSides: [SortSide.left, SortSide.right],
      );
      await pumpSort(
        tester,
        data: long,
        size: const Size(320, 568),
        textScale: 2,
        reducedMotion: true,
      );
      await start(tester);
      final position = tester.getCenter(card);
      await tester.pump(const Duration(seconds: 10));
      expect(tester.getCenter(card), position);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.ensureVisible(left);
      await tapSide(tester, 'debit');
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('backgrounding pauses and resuming continues without catch-up', (
    tester,
  ) async {
    await pumpSort(tester);
    await start(tester);
    await tester.pump(const Duration(seconds: 1));
    final position = tester.getCenter(card);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 10));
    expect(tester.getCenter(card), position);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getCenter(card).dy, greaterThan(position.dy));
  });

  for (final duringExit in [false, true]) {
    testWidgets(
      'controllers dispose safely during ${duringExit ? 'exit' : 'fall'}',
      (tester) async {
        await pumpSort(tester);
        await start(tester);
        if (duringExit) await tester.tap(left);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty data uses the existing empty state', (tester) async {
    await pumpSort(
      tester,
      data: const SortItRightQuestion(
        id: 'empty',
        topicId: 't',
        prompt: '',
        points: 0,
        itemsInOrder: [],
      ),
    );
    expect(find.text(QuestionType.sortItRight.emptyStateLabel), findsOneWidget);
    expect(card, findsNothing);
  });
}
