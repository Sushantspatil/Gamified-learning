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
  await tester.pumpAndSettle();
}

Future<void> finishMove(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

Future<void> tapSide(WidgetTester tester, String side) async {
  await tester.tap(find.byKey(ValueKey('sort-bucket-$side')));
  await finishMove(tester);
}

Future<void> buy(WidgetTester tester, String action) async {
  final target = find.byKey(Key('powerup-sort-$action'));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buy & use'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('classification is locked until the quick-buy debit finishes', (
    tester,
  ) async {
    final container = await pumpSort(tester);
    await start(tester);
    await tester.tap(find.byKey(const Key('powerup-sort-reveal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy & use'));
    await tester.pump();
    final target = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('sort-bucket-debit')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(target.onPressed, isNull);
    await tester.pumpAndSettle();
    expect(find.text('Cash A/C'), findsOneWidget);
    expect(find.text('Correct group: Real'), findsOneWidget);
    expect(container.read(walletControllerProvider).requireValue.coins, 75);
  });

  testWidgets('duplicate labels keep separate choices when undoing', (
    tester,
  ) async {
    const repeated = SortItRightQuestion(
      id: 'repeated',
      topicId: 'topic',
      prompt: 'Sort',
      points: 10,
      itemsInOrder: ['Same label', 'Same label', 'Third'],
      correctSides: [SortSide.left, SortSide.right, SortSide.left],
    );
    await pumpSort(tester, data: repeated);
    await start(tester);
    await tapSide(tester, 'debit');
    await tapSide(tester, 'credit');
    expect(find.text('2 correct · 0 wrong'), findsOneWidget);
    await buy(tester, 'undo');
    expect(find.text('2 / 3'), findsOneWidget);
    await tapSide(tester, 'debit');
    expect(find.text('1 correct · 1 wrong'), findsOneWidget);
  });

  testWidgets('intro, first item and progress; tap both sides submits once', (
    tester,
  ) async {
    final answers = <SortAnswer>[];
    await pumpSort(
      tester,
      onSubmit: (answer) => answers.add(answer as SortAnswer),
    );
    expect(find.text('5 items. Two groups.'), findsOneWidget);
    await start(tester);
    expect(find.text('Cash A/C'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    await tapSide(tester, 'debit');
    expect(find.text('Land A/C'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('1 correct · 0 wrong'), findsOneWidget);
    await tapSide(tester, 'credit');
    expect(find.text('1 correct · 1 wrong'), findsOneWidget);
    await tapSide(tester, 'credit');
    await tapSide(tester, 'debit');
    await tapSide(tester, 'credit');
    expect(answers, hasLength(1));
    expect(answers.single.selectedSides, [
      SortSide.left,
      SortSide.right,
      SortSide.right,
      SortSide.left,
      SortSide.right,
    ]);
    await tester.pump(const Duration(seconds: 2));
    expect(answers, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'swipes highlight direction, fully exit, then advance; short drag returns',
    (tester) async {
      await pumpSort(tester);
      await start(tester);
      final card = find.byKey(const Key('sort-active-card'));
      final original = tester.getCenter(card);
      final drag = await tester.startGesture(original);
      await drag.moveBy(const Offset(-120, 0));
      await tester.pump();
      final selected = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('sort-bucket-debit')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(selected.properties.selected, isTrue);
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getRect(card).right, lessThan(0));
      expect(find.text('Correct'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('2 / 5'), findsOneWidget);
      await tester.drag(card, const Offset(150, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getRect(card).left, greaterThan(393));
      expect(find.text('Wrong'), findsOneWidget);
      expect(find.text('Correct answer: Real'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      final short = await tester.startGesture(tester.getCenter(card));
      await short.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await short.up();
      await tester.pumpAndSettle();
      expect(find.text('3 / 5'), findsOneWidget);
      expect(tester.getCenter(card).dx, closeTo(original.dx, 1));
    },
  );

  testWidgets(
    'Undo removes wrong and correct history and charges the real wallet',
    (tester) async {
      final container = await pumpSort(tester);
      await start(tester);
      await tapSide(tester, 'debit');
      await tapSide(tester, 'credit');
      await buy(tester, 'undo');
      expect(find.text('Land A/C'), findsOneWidget);
      expect(find.text('1 correct · 0 wrong'), findsOneWidget);
      await buy(tester, 'undo');
      expect(find.text('Cash A/C'), findsOneWidget);
      expect(find.text('0 correct · 0 wrong'), findsOneWidget);
      expect(container.read(walletControllerProvider).requireValue.coins, 80);
      await tester.tap(find.byKey(const Key('powerup-sort-undo')));
      await tester.pumpAndSettle();
      expect(find.text('Buy & use'), findsNothing);
      await tapSide(tester, 'debit');
      expect(find.text('1 correct · 0 wrong'), findsOneWidget);
    },
  );

  testWidgets('Hint and Reveal debit once without completing the item', (
    tester,
  ) async {
    final container = await pumpSort(tester);
    await start(tester);
    await buy(tester, 'hint');
    expect(find.text(question.hint!), findsOneWidget);
    await buy(tester, 'reveal');
    expect(find.text('Correct group: Real'), findsOneWidget);
    expect(find.text('Cash A/C'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(container.read(walletControllerProvider).requireValue.coins, 65);
    await tester.tap(find.byKey(const Key('powerup-sort-reveal')));
    await tester.pumpAndSettle();
    expect(find.text('Buy & use'), findsNothing);
    await tapSide(tester, 'debit');
    expect(find.text('Correct group: Real'), findsNothing);
  });

  testWidgets('insufficient coins cannot apply a power-up', (tester) async {
    final container = await pumpSort(tester, coins: 0);
    await start(tester);
    await buy(tester, 'hint');
    expect(find.text(question.hint!), findsNothing);
    expect(container.read(walletControllerProvider).requireValue.coins, 0);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('portrait $size has no overflow and uses 16px margins', (
      tester,
    ) async {
      await pumpSort(tester, size: size);
      await start(tester);
      final left = tester.getRect(
        find.byKey(const ValueKey('sort-bucket-debit')),
      );
      final right = tester.getRect(
        find.byKey(const ValueKey('sort-bucket-credit')),
      );
      expect(left.left, 16);
      expect(right.right, size.width - 16);
      expect(
        tester.getRect(find.byKey(const Key('sort-active-card'))).top,
        greaterThan(left.bottom),
      );
      await buy(tester, 'hint');
      await buy(tester, 'reveal');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'large text wraps category labels and reduced motion still advances',
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
      await tester.ensureVisible(
        find.byKey(const ValueKey('sort-bucket-debit')),
      );
      await tapSide(tester, 'debit');
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty data and disposal during swipe are safe', (tester) async {
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
    await pumpSort(tester);
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('sort-bucket-debit')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
