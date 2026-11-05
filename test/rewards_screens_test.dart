import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/chests/presentation/screens/chest_screen.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';
import 'package:skillverse_app/features/rewards/domain/rewards_models.dart';
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
  Size size = const Size(800, 1800),
}) async {
  tester.view.physicalSize = size;
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
      final container = _launch(spinIndex: 9); // 30 coins (last segment)
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
      expect(segmentIndexAtPointer(angle, 10), 9);
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('You won 30 Coins.'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_coins(tester), '130');
      expect(find.text("You've already spun today."), findsOneWidget);
      // The button tells you when the next spin is, instead of just "no".
      expect(find.textContaining('Next spin in'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
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
      expect(_coins(tester), '115');
    });
  });

  group('Chest Box screen', () {
    void play(ProviderContainer container, int games, [String tag = 'g']) {
      final rewards = container.read(rewardsProvider.notifier);
      for (var i = 0; i < games; i++) {
        rewards.recordQuizCompleted('$tag-$i');
      }
    }

    String gems(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('gem_balance'))).data!;

    testWidgets('three chests sit side by side, earned order, closed art', (
      tester,
    ) async {
      await _show(tester, _launch(), const ChestScreen());

      final golden = find.byKey(const Key('chest-golden'));
      final cyber = find.byKey(const Key('chest-cyber'));
      final galaxy = find.byKey(const Key('chest-galaxy'));
      expect(
        tester.getTopLeft(golden).dx,
        lessThan(tester.getTopLeft(cyber).dx),
      );
      expect(
        tester.getTopLeft(cyber).dx,
        lessThan(tester.getTopLeft(galaxy).dx),
      );
      expect(tester.getTopLeft(golden).dy, tester.getTopLeft(cyber).dy);
      expect(tester.getTopLeft(cyber).dy, tester.getTopLeft(galaxy).dy);

      for (final chest in ['golden', 'cyber', 'galaxy']) {
        final frames = tester
            .widgetList<Image>(
              find.descendant(
                of: find.byKey(Key('chest-$chest')),
                matching: find.byType(Image),
              ),
            )
            .map((i) => (i.image as AssetImage).assetName)
            .toList();
        expect(frames, ['assets/chests/$chest/closed.png']);
      }
      expect(find.text('Golden Chest'), findsOneWidget);
      expect(find.text('Cyber Chest'), findsOneWidget);
      expect(find.text('Galaxy Chest'), findsOneWidget);
      expect(find.text('3 more games'), findsOneWidget);
      expect(find.text('6 more games'), findsOneWidget);
      expect(find.text('10 more games'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);
      expect(find.text('Next: Golden Chest in 3 games'), findsOneWidget);
    });

    testWidgets('fits a small phone without overflow', (tester) async {
      final container = _launch();
      play(container, 3);
      await _show(
        tester,
        container,
        const ChestScreen(),
        size: const Size(720, 1280), // 360 x 640 logical
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tap to open'), findsOneWidget);

      // The opening view and its reward also fit this screen.
      await tester.tap(find.byKey(const Key('chest-golden')));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final collect = tester.getRect(find.byKey(const Key('chest_collect')));
      expect(collect.bottom, lessThanOrEqualTo(640));
      await tester.tap(find.byKey(const Key('chest_collect')));
      await tester.pumpAndSettle();
    });

    testWidgets('locked chest explains and cannot be bought without coins', (
      tester,
    ) async {
      final container = _launch();
      play(container, 2);
      await _show(tester, container, const ChestScreen());
      expect(find.text('2/10'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chest-golden')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Finish 1 more game to earn it for free, or open it now with coins.',
        ),
        findsOneWidget,
      );
      // 100 coins cannot pay the 200-coin Golden chest.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('chest_force_open')))
            .onPressed,
        isNull,
      );
      expect(find.text('You need 100 more coins.'), findsOneWidget);

      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(_coins(tester), '100');
      expect(container.read(rewardsProvider).chestProgress, 2);
      expect(find.byKey(const Key('chest_stage_title')), findsNothing);
    });

    testWidgets('paying opens it in the large centred view, once', (
      tester,
    ) async {
      final container = _launch(); // first wheel prize: +100 coins
      container.read(rewardsProvider.notifier)
        ..startSpin()
        ..completeSpin();
      play(container, 2);
      await _show(tester, container, const ChestScreen());
      expect(_coins(tester), '200');

      await tester.tap(find.byKey(const Key('chest-golden')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chest_force_open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The stage is on screen, centred, larger than the row tile; nothing is
      // charged until the animation has finished.
      final chest = find.byKey(const Key('chest_stage_chest'));
      expect(chest, findsOneWidget);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getCenter(chest).dx, closeTo(screen.width / 2, 1));
      expect(tester.getSize(chest).height, greaterThan(150));
      expect(find.text('Opening…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_coins(tester), '200');

      await tester.pumpAndSettle();
      expect(find.text('+40 Coins'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chest_collect')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chest_stage_chest')), findsNothing);
      expect(_coins(tester), '40'); // 200 - 200 + 40
      expect(container.read(rewardsProvider).chestProgress, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an earned chest opens free; rapid taps claim it once', (
      tester,
    ) async {
      final container = _launch();
      play(container, 3);
      await _show(tester, container, const ChestScreen());
      expect(find.text('Tap to open'), findsOneWidget);
      expect(find.text('A chest is ready. Tap it to open!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chest-golden')));
      await tester.tap(
        find.byKey(const Key('chest-golden')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_coins(tester), '100'); // not paid mid-animation

      await tester.pumpAndSettle();
      expect(find.text('+40 Coins'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chest_collect')));
      await tester.pumpAndSettle();
      expect(_coins(tester), '140'); // exactly one claim
      expect(
        container.read(rewardsProvider).chestReady(ChestTier.golden),
        isFalse,
      );
      expect(find.text('Tap to open'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cyber shows the cosmetic, Galaxy adds gems', (tester) async {
      final container = _launch();
      play(container, 10);
      await _show(tester, container, const ChestScreen());
      expect(find.text('Tap to open'), findsNWidgets(3));
      expect(gems(tester), '0');

      await tester.tap(find.byKey(const Key('chest-cyber')));
      await tester.pumpAndSettle();
      expect(find.text('Scholar unlocked!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chest_collect')));
      await tester.pumpAndSettle();
      expect(container.read(rewardsProvider).ownedAvatars, {'avatar-scholar'});
      expect(_coins(tester), '100');

      await tester.tap(find.byKey(const Key('chest-galaxy')));
      await tester.pumpAndSettle();
      expect(find.text('+10 Gems'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chest_collect')));
      await tester.pumpAndSettle();
      expect(gems(tester), '10');
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
      expect(find.text('Buy Scholar?'), findsOneWidget);
      expect(find.text('After buying'), findsOneWidget);
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

    testWidgets('what you cannot afford says how many coins are missing', (
      tester,
    ) async {
      final container = _launch();
      await _show(tester, container, const ShopScreen());

      // 250 coins with 100 in the purse: the button says so and is off.
      expect(buyIn('Genius'), findsNothing);
      expect(find.text('Need 150 more'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Need 150 more'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(_coins(tester), '100');
      expect(container.read(rewardsProvider).ownedAvatars, isEmpty);
    });

    testWidgets('fits a small phone with large text, on every tab', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await _show(
        tester,
        _launch(),
        const ShopScreen(),
        size: const Size(720, 1280),
      );
      for (final tab in ['Avatars', 'Profile Frames', 'Power-ups']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });

    testWidgets('tapping an item puts it on the character to try on', (
      tester,
    ) async {
      final container = _launch();
      await _show(tester, container, const ShopScreen());

      expect(find.text('Your look'), findsOneWidget);
      await tester.tap(find.text('Explorer'));
      await tester.pumpAndSettle();
      expect(find.text('Previewing: Explorer'), findsOneWidget);
      // Trying it on costs nothing and equips nothing.
      expect(_coins(tester), '100');
      expect(container.read(rewardsProvider).equippedAvatar, isNull);
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
      expect(find.text('×0'), findsNWidgets(2));
      expect(find.text('Coming soon'), findsOneWidget);

      await tester.tap(buyIn('Hint Token'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Purchase'));
      await tester.pumpAndSettle();
      expect(find.text('×1'), findsOneWidget);
      expect(_coins(tester), '50');
      // Consumable: can be bought again.
      expect(buyIn('Hint Token'), findsOneWidget);
    });
  });

  testWidgets('all three screens show the same, live coin balance', (
    tester,
  ) async {
    final container = _launch(spinIndex: 0); // 100 coins
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
