import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/shared/widgets/app_button.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/chests/presentation/screens/chest_screen.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';
import 'package:skillverse_app/features/shop/presentation/screens/shop_screen.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/screens/spin_wheel_screen.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/widgets/spin_wheel_painter.dart';

class _FixedRandom implements math.Random {
  final int index;
  _FixedRandom(this.index);
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => index;
}

late LocalStorageService _storage;

ProviderContainer _launch({int spinIndex = 0}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_storage),
      rewardsRandomProvider.overrideWithValue(_FixedRandom(spinIndex)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _show(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _coins(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('coin_balance'))).data!;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.create();
  });

  group('Spin the Wheel screen', () {
    testWidgets('stops on the chosen segment, pays once, locks the day', (
      tester,
    ) async {
      final container = _launch(spinIndex: 2); // 30 coins
      await _show(tester, container, const SpinWheelScreen());
      expect(_coins(tester), '100');

      await tester.tap(find.text('Spin Now'));
      // A second tap in the same instant must do nothing.
      await tester.tap(find.text('Spin Now'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Spinning…'), findsOneWidget);
      expect(_coins(tester), '100'); // not paid until it stops

      await tester.pumpAndSettle();
      // The wheel rests on the same segment the dialog announces.
      final wheel = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SpinWheelPainter,
      );
      final rotation = tester
          .widget<Transform>(
            find.ancestor(of: wheel, matching: find.byType(Transform)).first,
          )
          .transform;
      final angle = math.atan2(rotation.storage[1], rotation.storage[0]);
      expect(segmentIndexAtPointer(angle, 6), 2);
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('You won 30 Coins.'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_coins(tester), '130');
      expect(
        find.text("You've already spun today. Come back tomorrow!"),
        findsOneWidget,
      );
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays disabled after the app is reopened', (tester) async {
      final first = _launch(spinIndex: 1);
      first.read(rewardsProvider.notifier)
        ..startSpin()
        ..completeSpin();

      await _show(tester, _launch(), const SpinWheelScreen());
      expect(find.byKey(const Key('already_spun')), findsOneWidget);
      expect(_coins(tester), '120');
    });
  });

  group('Chest Box screen', () {
    testWidgets('progress, locked state, ready state, single claim', (
      tester,
    ) async {
      final container = _launch();
      final rewards = container.read(rewardsProvider.notifier);
      rewards
        ..recordQuizCompleted('a')
        ..recordQuizCompleted('b');
      await _show(tester, container, const ChestScreen());

      expect(find.text('Treasure Chest'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(
        find.text('Complete 3 quizzes to unlock your chest.'),
        findsOneWidget,
      );
      expect(find.text('Reward: 50 Coins'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );

      rewards.recordQuizCompleted('c');
      await tester.pumpAndSettle();
      expect(find.text('Your chest is ready!'), findsOneWidget);
      expect(
        find.text('Open your chest to start your next reward cycle.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Open Chest'));
      await tester.tap(
        find.text('Open Chest'),
        warnIfMissed: false,
      ); // rapid second tap
      await tester.pump(const Duration(milliseconds: 200));
      expect(_coins(tester), '100'); // paid only after the animation
      await tester.pumpAndSettle();
      expect(find.text('You received 50 Coins.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(_coins(tester), '150');
      expect(find.text('0/3'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Shop screen', () {
    Finder tile(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(DecoratedBox));
    Finder buyIn(String name) => find.descendant(
      of: tile(name).first,
      matching: find.widgetWithText(FilledButton, 'Buy'),
    );

    testWidgets('cancel keeps coins; confirm deducts; then equip', (
      tester,
    ) async {
      final container = _launch();
      await _show(tester, container, const ShopScreen());

      expect(find.text('Scholar'), findsOneWidget);
      expect(find.text('100 Coins'), findsOneWidget);
      expect(find.text('250 Coins'), findsOneWidget);

      await tester.tap(buyIn('Scholar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Do you want to purchase Scholar for 100 Coins?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_coins(tester), '100');

      await tester.tap(buyIn('Scholar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Purchase'));
      await tester.pumpAndSettle();
      expect(
        find.text('Purchase successful! Scholar is now yours.'),
        findsOneWidget,
      );
      expect(_coins(tester), '0');
      expect(find.text('Owned'), findsOneWidget);
      expect(buyIn('Scholar'), findsNothing);

      await tester.tap(find.text('Equip'));
      await tester.pumpAndSettle();
      expect(find.text('Equipped'), findsWidgets);
      expect(container.read(rewardsProvider).equippedAvatar, 'avatar-scholar');
    });

    testWidgets('not enough coins shows a message and changes nothing', (
      tester,
    ) async {
      final container = _launch();
      await _show(tester, container, const ShopScreen());

      await tester.tap(buyIn('Genius'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Purchase'));
      await tester.pumpAndSettle();

      expect(
        find.text('Not enough coins. Earn more coins to purchase this item.'),
        findsOneWidget,
      );
      expect(_coins(tester), '100');
      expect(container.read(rewardsProvider).ownedAvatars, isEmpty);
    });

    testWidgets('frames and power-ups tabs; tokens stack; retry is locked', (
      tester,
    ) async {
      final container = _launch();
      container.read(rewardsProvider.notifier).recordQuizCompleted('x');
      await _show(tester, container, const ShopScreen());

      await tester.tap(find.text('Profile Frames'));
      await tester.pumpAndSettle();
      expect(find.text('Bronze Frame'), findsOneWidget);
      expect(find.text('Gold Frame'), findsOneWidget);
      expect(find.text('150 Coins'), findsOneWidget);

      await tester.tap(find.text('Power-ups'));
      await tester.pumpAndSettle();
      expect(find.text('Hint Token'), findsOneWidget);
      expect(find.text('You have: 0'), findsNWidgets(2));
      expect(find.text('Coming soon'), findsOneWidget);

      await tester.tap(buyIn('Hint Token'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Purchase'));
      await tester.pumpAndSettle();
      expect(find.text('You have: 1'), findsOneWidget);
      expect(_coins(tester), '50');
      // Consumable: can be bought again.
      expect(buyIn('Hint Token'), findsOneWidget);
    });
  });

  testWidgets('all three screens show the same, live coin balance', (
    tester,
  ) async {
    final container = _launch(spinIndex: 5); // 100 coins
    for (final screen in const [
      SpinWheelScreen(),
      ShopScreen(),
      ChestScreen(),
    ]) {
      await _show(tester, container, screen);
      expect(_coins(tester), '100');
    }
    container.read(rewardsProvider.notifier)
      ..startSpin()
      ..completeSpin();
    await tester.pumpAndSettle();
    expect(_coins(tester), '200');
  });
}
