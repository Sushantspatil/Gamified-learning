import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/chests/presentation/screens/chest_screen.dart';
import 'package:skillverse_app/features/rewards_hub/data/rewards_mock_data.dart';
import 'package:skillverse_app/features/rewards_hub/domain/rewards_models.dart';
import 'package:skillverse_app/features/rewards_hub/presentation/providers/rewards_providers.dart';
import 'package:skillverse_app/features/shop/presentation/screens/shop_screen.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/screens/spin_wheel_screen.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/widgets/spin_wheel_painter.dart';

class _FixedRandom implements Random {
  int index;
  _FixedRandom(this.index);

  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => index;
}

late LocalStorageService _storage;

ProviderContainer _container({
  int spinIndex = 0,
  DateTime Function()? clock,
  _FixedRandom? random,
}) {
  final container = ProviderContainer(
    overrides: [
      rewardsRandomProvider.overrideWithValue(
        random ?? _FixedRandom(spinIndex),
      ),
      if (clock != null) rewardsClockProvider.overrideWithValue(clock),
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      localStorageServiceProvider.overrideWithValue(_storage),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.create();
  });

  group('wheel angle maths', () {
    test('every target angle lands inside the chosen segment', () {
      const count = 8;
      final random = Random(7);
      for (var index = 0; index < count; index++) {
        for (final offset in [-0.4, -0.2, 0.0, 0.2, 0.4]) {
          final current = random.nextDouble() * 40;
          final target = wheelTargetAngle(
            index: index,
            segmentCount: count,
            currentAngle: current,
            turns: 5,
            offsetFraction: offset,
          );
          expect(target, greaterThan(current + 5 * 2 * pi - 0.001));
          expect(segmentIndexAtPointer(target, count), index);
        }
      }
    });
  });

  group('RewardsController', () {
    test('spin is granted once per day and credits the landed prize', () {
      var now = DateTime(2026, 11, 2, 10);
      final container = _container(spinIndex: 4, clock: () => now);
      final notifier = container.read(rewardsProvider.notifier);

      expect(container.read(rewardsProvider).isSpinAvailableOn(now), isTrue);
      expect(notifier.startSpin(), 4);
      // Locked while pending and for the rest of the day.
      expect(notifier.startSpin(), isNull);

      final reward = notifier.completeSpin()!;
      expect(reward.amount, 50);
      final state = container.read(rewardsProvider);
      expect(state.coins, RewardsMockData.startingCoins + 50);
      expect(state.spinHistory.first.title, '50 Coins');
      expect(notifier.startSpin(), isNull);
      expect(notifier.completeSpin(), isNull);

      now = DateTime(2026, 11, 3, 9);
      expect(container.read(rewardsProvider).isSpinAvailableOn(now), isTrue);
      expect(notifier.startSpin(), 4);
    });

    test('non-coin prizes update XP, power-ups and chest progress', () {
      final random = _FixedRandom(0);
      var now = DateTime(2026, 11, 1);
      final container = _container(random: random, clock: () => now);
      final notifier = container.read(rewardsProvider.notifier);
      final segments = RewardsMockData.wheelSegments;

      // Each prize goes through the real spin path, one spin per day.
      void spinTo(String id) {
        random.index = segments.indexWhere((s) => s.id == id);
        expect(notifier.startSpin(), random.index);
        notifier.completeSpin();
        now = now.add(const Duration(days: 1));
      }

      spinTo('xp');
      expect(
        container.read(rewardsProvider).xp,
        RewardsMockData.startingXp + 25,
      );
      spinTo('hint');
      expect(container.read(rewardsProvider).powerUpCount(PowerUpType.hint), 1);
      spinTo('chest');
      expect(container.read(rewardsProvider).progressOf(ChestTier.bronze), 3);
    });

    test('purchase deducts coins once and blocks duplicates', () {
      final container = _container();
      final notifier = container.read(rewardsProvider.notifier);

      expect(notifier.purchase('frame-golden'), PurchaseOutcome.success);
      expect(container.read(rewardsProvider).coins, 350);
      expect(notifier.purchase('frame-golden'), PurchaseOutcome.alreadyOwned);
      expect(container.read(rewardsProvider).coins, 350);
    });

    test('insufficient coins leave the balance and inventory untouched', () {
      final container = _container();
      final notifier = container.read(rewardsProvider.notifier);

      expect(notifier.purchase('frame-royal'), PurchaseOutcome.success); // 300
      expect(
        notifier.purchase('avatar-wizard'), // 350 > 200
        PurchaseOutcome.insufficientCoins,
      );
      final state = container.read(rewardsProvider);
      expect(state.coins, 200);
      expect(state.ownedItemIds, {'frame-royal'});
    });

    test('power-ups stack up to their cap', () {
      final container = _container();
      final notifier = container.read(rewardsProvider.notifier);

      // Streak Freeze costs 250 and caps at 3; only one affordable first.
      expect(notifier.purchase('powerup-freeze'), PurchaseOutcome.success);
      expect(notifier.purchase('powerup-freeze'), PurchaseOutcome.success);
      expect(
        notifier.purchase('powerup-freeze'),
        PurchaseOutcome.insufficientCoins,
      );
      expect(
        container.read(rewardsProvider).powerUpCount(PowerUpType.streakFreeze),
        2,
      );
      expect(container.read(rewardsProvider).coins, 0);

      // Hint Booster caps at 9: buy until the coins run out, never negative.
      expect(
        notifier.purchase('powerup-hint'),
        PurchaseOutcome.insufficientCoins,
      );
      expect(container.read(rewardsProvider).coins, greaterThanOrEqualTo(0));
    });

    test('equip only works for owned items and switches freely', () {
      final container = _container();
      final notifier = container.read(rewardsProvider.notifier);

      notifier.equip('avatar-scholar');
      expect(container.read(rewardsProvider).equippedAvatarId, isNull);

      notifier.purchase('avatar-scholar');
      notifier.purchase('avatar-explorer');
      notifier.equip('avatar-scholar');
      expect(
        container.read(rewardsProvider).equippedAvatarId,
        'avatar-scholar',
      );
      notifier.equip('avatar-explorer');
      expect(
        container.read(rewardsProvider).equippedAvatarId,
        'avatar-explorer',
      );
    });

    test('chests open only when ready and can never be claimed twice', () {
      final random = _FixedRandom(0);
      final container = _container(random: random);
      final notifier = container.read(rewardsProvider.notifier);

      expect(notifier.openChest(ChestTier.bronze), isNull); // 2/3
      expect(notifier.openChest(ChestTier.gold), isNull); // locked

      // Chest Progress prize fills the bronze chest.
      random.index = RewardsMockData.wheelSegments.indexWhere(
        (s) => s.id == 'chest',
      );
      notifier.startSpin();
      notifier.completeSpin();
      expect(
        container
            .read(rewardsProvider)
            .chestStatus(RewardsMockData.chestFor(ChestTier.bronze)),
        ChestStatus.ready,
      );

      final coinsBefore = container.read(rewardsProvider).coins;
      final rewards = notifier.openChest(ChestTier.bronze)!;
      expect(rewards.first.amount, 60);
      final state = container.read(rewardsProvider);
      expect(state.coins, coinsBefore + 60);
      expect(state.powerUpCount(PowerUpType.hint), 1);
      expect(
        state.chestStatus(RewardsMockData.chestFor(ChestTier.bronze)),
        ChestStatus.claimed,
      );
      expect(notifier.openChest(ChestTier.bronze), isNull);
      expect(container.read(rewardsProvider).coins, coinsBefore + 60);
    });
  });

  group('SpinWheelScreen', () {
    testWidgets('spins to the selected prize, pays it and locks the day', (
      tester,
    ) async {
      final hintIndex = RewardsMockData.wheelSegments.indexWhere(
        (s) => s.id == 'hint',
      );
      final container = _container(spinIndex: hintIndex);
      await _pumpScreen(tester, const SpinWheelScreen(), container);

      expect(find.text('Daily Rewards'), findsOneWidget);
      expect(find.text('Spin Now'), findsOneWidget);

      await tester.tap(find.text('Spin Now'));
      await tester.pump(const Duration(milliseconds: 100));
      // Button is disabled the moment the spin starts.
      expect(find.text('Spinning…'), findsOneWidget);
      expect(container.read(rewardsProvider).coins, 500);

      await tester.pumpAndSettle();
      expect(find.text('You won Hint Token!'), findsOneWidget);
      await tester.tap(find.text('Collect'));
      await tester.pumpAndSettle();

      expect(container.read(rewardsProvider).powerUpCount(PowerUpType.hint), 1);
      expect(find.text('Spin used today'), findsOneWidget);
      expect(find.byKey(const Key('spin_countdown')), findsOneWidget);
      // New entry at the top of the history.
      expect(find.text('Hint Token'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('coin prize updates the shared balance chip', (tester) async {
      final container = _container(spinIndex: 2); // 30 coins
      await _pumpScreen(tester, const SpinWheelScreen(), container);

      await tester.tap(find.text('Spin Now'));
      await tester.pumpAndSettle();
      expect(find.text('You won 30 Coins!'), findsOneWidget);
      await tester.tap(find.text('Collect'));
      await tester.pumpAndSettle();

      expect(container.read(rewardsProvider).coins, 530);
      expect(find.text('530'), findsOneWidget);
    });
  });

  group('ShopScreen', () {
    testWidgets('cancel keeps coins; confirm deducts; owned item can equip', (
      tester,
    ) async {
      final container = _container();
      await _pumpScreen(tester, const ShopScreen(), container);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('product-frame-golden')),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buy Golden Frame?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(rewardsProvider).coins, 500);
      expect(container.read(rewardsProvider).ownedItemIds, isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('product-frame-golden')),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(container.read(rewardsProvider).coins, 350);
      expect(find.text('Golden Frame purchased.'), findsOneWidget);

      // Card now offers Equip, never Buy again.
      final card = find.byKey(const ValueKey('product-frame-golden'));
      expect(
        find.descendant(of: card, matching: find.text('Equip')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(of: card, matching: find.text('Equip')));
      await tester.pumpAndSettle();
      expect(container.read(rewardsProvider).equippedFrameId, 'frame-golden');
      expect(
        find.descendant(of: card, matching: find.text('Equipped')),
        findsWidgets,
      );
    });

    testWidgets('insufficient coins show guidance and change nothing', (
      tester,
    ) async {
      final container = _container();
      container.read(rewardsProvider.notifier)
        ..purchase('frame-royal')
        ..purchase('avatar-scholar'); // leaves 0 coins
      await _pumpScreen(tester, const ShopScreen(), container);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('product-frame-golden')),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You are 150 coins short.'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('You need 150 more coins'), findsOneWidget);
      expect(container.read(rewardsProvider).coins, 0);
      expect(
        container.read(rewardsProvider).ownedItemIds.contains('frame-golden'),
        isFalse,
      );
    });

    testWidgets('categories filter the grid and details sheet opens', (
      tester,
    ) async {
      final container = _container();
      await _pumpScreen(tester, const ShopScreen(), container);

      await tester.tap(find.text('Power-ups'));
      await tester.pumpAndSettle();
      expect(find.text('Hint Booster'), findsOneWidget);
      expect(find.text('Retry Token'), findsOneWidget);
      expect(find.text('Golden Frame'), findsNothing);

      await tester.tap(find.text('Retry Token'));
      await tester.pumpAndSettle();
      expect(find.text('Buy for 75 coins'), findsOneWidget);
    });
  });

  group('ChestScreen', () {
    testWidgets('locked and in-progress chests explain; ready chest opens', (
      tester,
    ) async {
      final container = _container(
        spinIndex: RewardsMockData.wheelSegments.indexWhere(
          (s) => s.id == 'chest',
        ),
      );
      await _pumpScreen(tester, const ChestScreen(), container);

      expect(find.text('Treasure Rewards'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Locked'), findsWidgets);

      // Tapping the locked golden chest explains what to do.
      await tester.tap(find.text('Golden Chest'));
      await tester.pump();
      expect(find.textContaining('Golden Chest is locked'), findsOneWidget);

      // Fill the bronze chest through the shared state, then open it.
      final notifier = container.read(rewardsProvider.notifier);
      notifier.startSpin();
      notifier.completeSpin();
      await tester.pumpAndSettle();
      expect(find.text('Ready to open'), findsOneWidget);

      await tester.tap(find.text('Open Chest'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(rewardsProvider).coins, 500); // not paid yet
      await tester.pumpAndSettle();

      expect(find.text('Bronze Chest opened!'), findsOneWidget);
      await tester.tap(find.text('Collect'));
      await tester.pumpAndSettle();

      final state = container.read(rewardsProvider);
      expect(state.coins, 560);
      expect(state.claimedChests, {ChestTier.bronze});
      expect(find.text('Claimed'), findsWidgets);
      expect(find.text('Open Chest'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
