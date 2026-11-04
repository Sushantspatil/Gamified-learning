import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/questions/data/datasources/mock/question_mock_datasource.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/questions/presentation/providers/question_providers.dart';
import 'package:skillverse_app/features/quiz/data/datasources/mock/quiz_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';
import 'package:skillverse_app/features/rewards/data/rewards_catalog.dart';
import 'package:skillverse_app/features/rewards/data/rewards_store.dart';
import 'package:skillverse_app/features/rewards/domain/rewards_models.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/widgets/spin_wheel_painter.dart';

class FixedRandom implements Random {
  int index;
  FixedRandom(this.index);
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => index;
}

late LocalStorageService storage;

/// A fresh "app launch" on the same device storage.
ProviderContainer launch({FixedRandom? random, DateTime Function()? clock}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      if (random != null) rewardsRandomProvider.overrideWithValue(random),
      if (clock != null) rewardsClockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

RewardsController rewards(ProviderContainer c) =>
    c.read(rewardsProvider.notifier);
RewardsState stateOf(ProviderContainer c) => c.read(rewardsProvider);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
  });

  group('coins and persistence', () {
    test('a new profile starts with 100 coins, saved once', () {
      expect(stateOf(launch()).coins, 100);
      expect(storage.getString(RewardsStore.key), isNotNull);
    });

    test('the balance is not reset on relaunch', () {
      final first = launch();
      rewards(first).purchase('frame-bronze'); // 100 -> 50
      expect(stateOf(first).coins, 50);

      final second = launch();
      expect(stateOf(second).coins, 50);
      expect(stateOf(second).ownedFrames, {'frame-bronze'});
    });

    test('an invalid or missing saved balance falls back to 100', () async {
      for (final raw in [
        'not json',
        '{"coins": "lots"}',
        '{"coins": -5}',
        '[]',
      ]) {
        await storage.setString(RewardsStore.key, raw);
        expect(stateOf(launch()).coins, 100, reason: raw);
      }
    });

    test('bad optional fields are ignored, a valid balance is kept', () async {
      await storage.setString(
        RewardsStore.key,
        jsonEncode({
          'coins': 240,
          'chestProgress': 99,
          'ownedAvatars': ['avatar-scholar', 'avatar-nope', 7],
          'powerUps': {'hint': -3, 'fiftyFifty': 2, 'bogus': 1},
          'pendingSpinReward': 12345,
        }),
      );
      final s = stateOf(launch());
      expect(s.coins, 240);
      expect(s.chestProgress, 3); // clamped
      expect(s.ownedAvatars, {'avatar-scholar'});
      expect(s.powerUps, {PowerUpType.fiftyFifty: 2});
      expect(s.pendingSpinReward, isNull);
    });

    test('everything survives a restart', () {
      final first = launch(random: FixedRandom(0)); // 100 coins prize
      final c = rewards(first);
      c.startSpin();
      c.completeSpin();
      c.purchase('avatar-scholar');
      c.equip('avatar-scholar');
      c.purchase('frame-bronze');
      c.equip('frame-bronze');
      c.purchase('powerup-hint');
      c.recordQuizCompleted('a');

      final s = stateOf(launch());
      expect(s.coins, 100 + 100 - 100 - 50 - 50);
      expect(s.equippedAvatar, 'avatar-scholar');
      expect(s.equippedFrame, 'frame-bronze');
      expect(s.powerUpCount(PowerUpType.hint), 1);
      expect(s.chestProgress, 1);
      expect(s.processedQuizIds, ['a']);
      expect(s.lastSpinReward, 100);
    });
  });

  group('spin the wheel', () {
    test('ten segments with the configured prizes', () {
      expect(RewardsCatalog.wheel.map((s) => s.coins), [
        100,
        15,
        50,
        20,
        75,
        10,
        60,
        25,
        40,
        30,
      ]);
    });

    test(
      'each segment is chosen uniformly: selection is nextInt(10)',
      () async {
        final seen = <int>{};
        for (var i = 0; i < 10; i++) {
          SharedPreferences.setMockInitialValues({}); // fresh device each time
          storage = await LocalStorageService.create();
          final random = FixedRandom(i);
          final c = launch(random: random);
          final index = rewards(c).startSpin();
          expect(index, i);
          seen.add(RewardsCatalog.wheel[index!].coins);
        }
        expect(seen, {100, 15, 50, 20, 75, 10, 60, 25, 40, 30});

        // The generator is asked for one of exactly ten equal outcomes.
        SharedPreferences.setMockInitialValues({});
        storage = await LocalStorageService.create();
        var asked = 0;
        rewards(launch(random: _SpyRandom((max) => asked = max))).startSpin();
        expect(asked, 10);
      },
    );

    test('a spin pays once and blocks a second spin the same day', () {
      final c = launch(random: FixedRandom(2)); // 50 coins
      final r = rewards(c);

      expect(r.startSpin(), 2);
      expect(r.startSpin(), isNull); // rapid second tap
      expect(stateOf(c).coins, 100); // not paid until the wheel stops
      expect(r.completeSpin(), 50);
      expect(r.completeSpin(), isNull); // cannot pay twice
      expect(stateOf(c).coins, 150);
      expect(r.startSpin(), isNull);
      expect(r.canSpinToday(), isFalse);
    });

    test(
      'the next local day allows a new spin; the status survives restart',
      () {
        var now = DateTime(2026, 11, 2, 23, 59);
        final c = launch(random: FixedRandom(0), clock: () => now);
        rewards(c).startSpin();
        rewards(c).completeSpin();

        final sameDayRelaunch = launch(
          random: FixedRandom(0),
          clock: () => now,
        );
        expect(rewards(sameDayRelaunch).canSpinToday(), isFalse);

        now = DateTime(2026, 11, 3, 0, 1);
        final nextDay = launch(random: FixedRandom(1), clock: () => now);
        expect(rewards(nextDay).canSpinToday(), isTrue);
        expect(rewards(nextDay).startSpin(), 1);
      },
    );

    test('winding the clock back does not give an extra spin', () {
      var now = DateTime(2026, 11, 5);
      final c = launch(random: FixedRandom(0), clock: () => now);
      rewards(c).startSpin();
      rewards(c).completeSpin();
      now = DateTime(2026, 11, 1);
      expect(rewards(c).canSpinToday(), isFalse);
    });

    test(
      'closing the app mid-spin pays the prize exactly once on relaunch',
      () {
        final first = launch(random: FixedRandom(4)); // 75 coins
        rewards(first).startSpin(); // never completed
        expect(stateOf(first).coins, 100);

        final second = launch();
        expect(stateOf(second).coins, 175);
        expect(stateOf(second).pendingSpinReward, isNull);
        final third = launch();
        expect(stateOf(third).coins, 175);
      },
    );

    test('the target angle lands on the chosen segment for every segment', () {
      final random = Random(3);
      for (var i = 0; i < 10; i++) {
        for (final offset in [-0.4, 0.0, 0.4]) {
          final target = wheelTargetAngle(
            index: i,
            segmentCount: 10,
            currentAngle: random.nextDouble() * 30,
            turns: 5,
            offsetFraction: offset,
          );
          expect(segmentIndexAtPointer(target, 10), i);
        }
      }
    });
  });

  group('chest box', () {
    test('three completed quizzes unlock it; opening pays 50 and resets', () {
      final c = launch();
      final r = rewards(c);
      expect(stateOf(c).chestProgress, 0);
      r.recordQuizCompleted('q1');
      r.recordQuizCompleted('q2');
      expect(stateOf(c).chestReady, isFalse);
      expect(r.openChest(), isFalse);
      expect(stateOf(c).coins, 100);

      r.recordQuizCompleted('q3');
      expect(stateOf(c).chestReady, isTrue);
      expect(r.openChest(), isTrue);
      expect(stateOf(c).coins, 150);
      expect(stateOf(c).chestProgress, 0);
      expect(r.openChest(), isFalse); // no double claim
      expect(stateOf(c).coins, 150);
    });

    test('the same attempt never counts twice', () {
      final c = launch();
      for (var i = 0; i < 5; i++) {
        rewards(c).recordQuizCompleted('same-attempt');
      }
      expect(stateOf(c).chestProgress, 1);
      expect(stateOf(launch()).chestProgress, 1); // and after restart
      rewards(launch()).recordQuizCompleted('same-attempt');
      expect(stateOf(launch()).chestProgress, 1);
    });

    test(
      'a full chest does not collect extra progress, then a new cycle starts',
      () {
        final c = launch();
        final r = rewards(c);
        for (final id in ['a', 'b', 'c', 'd', 'e']) {
          r.recordQuizCompleted(id);
        }
        expect(stateOf(c).chestProgress, 3);
        r.openChest();
        expect(stateOf(c).chestProgress, 0); // d and e were not banked
        r.recordQuizCompleted('f');
        expect(stateOf(c).chestProgress, 1);
      },
    );
  });

  group('shop', () {
    test('catalogue has the requested products and prices', () {
      expect(
        {for (final p in RewardsCatalog.avatars) p.name: p.price},
        {'Scholar': 100, 'Explorer': 150, 'Champion': 200, 'Genius': 250},
      );
      expect(
        {for (final p in RewardsCatalog.frames) p.name: p.price},
        {'Bronze Frame': 50, 'Silver Frame': 100, 'Gold Frame': 150},
      );
      expect(
        {for (final p in RewardsCatalog.powerUps) p.name: p.price},
        {'Hint Token': 50, 'Retry Token': 75, '50/50 Token': 100},
      );
    });

    test('purchase deducts once; owned cosmetics cannot be bought again', () {
      final c = launch();
      final r = rewards(c);
      expect(r.purchase('avatar-scholar'), PurchaseOutcome.success);
      expect(stateOf(c).coins, 0);
      expect(r.purchase('avatar-scholar'), PurchaseOutcome.alreadyOwned);
      expect(stateOf(c).coins, 0);
    });

    test('not enough coins changes nothing and never goes negative', () {
      final c = launch();
      final r = rewards(c);
      expect(r.purchase('avatar-genius'), PurchaseOutcome.notEnoughCoins);
      expect(stateOf(c).coins, 100);
      expect(stateOf(c).ownedAvatars, isEmpty);
    });

    test('equip needs ownership; one avatar and one frame at a time', () {
      final c = launch();
      final r = rewards(c);
      r.equip('frame-bronze');
      expect(stateOf(c).equippedFrame, isNull);

      r.purchase('frame-bronze'); // 50
      r.purchase('frame-bronze');
      r.equip('frame-bronze');
      expect(stateOf(c).equippedFrame, 'frame-bronze');
      expect(stateOf(c).coins, 50);
    });

    test('power-ups stack, and inventory only drops on use, never below 0', () {
      final c = launch();
      final r = rewards(c);
      expect(r.consumePowerUp(PowerUpType.hint), isFalse);
      expect(r.purchase('powerup-hint'), PurchaseOutcome.success);
      expect(r.purchase('powerup-hint'), PurchaseOutcome.success);
      expect(stateOf(c).powerUpCount(PowerUpType.hint), 2);
      expect(stateOf(c).coins, 0);

      expect(r.consumePowerUp(PowerUpType.hint), isTrue);
      expect(r.consumePowerUp(PowerUpType.hint), isTrue);
      expect(r.consumePowerUp(PowerUpType.hint), isFalse);
      expect(stateOf(c).powerUpCount(PowerUpType.hint), 0);
    });

    test('Retry Token is listed but cannot be bought yet', () {
      final c = launch();
      expect(rewards(c).purchase('powerup-retry'), PurchaseOutcome.unavailable);
      expect(stateOf(c).coins, 100);
    });
  });

  group('quiz completion feeds the chest', () {
    test(
      'a finished MCQ attempt counts once; an abandoned one never does',
      () async {
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            questionDatasourceProvider.overrideWithValue(
              QuestionMockDatasource(),
            ),
            quizDatasourceProvider.overrideWithValue(QuizMockDatasource()),
          ],
        );
        addTearDown(container.dispose);
        const request = QuizSessionRequest(
          topicId: 'accounting-chapter-1-topic-1',
          quizType: QuestionType.mcq,
        );

        Future<void> play({required bool finish}) async {
          final sub = container.listen(
            quizControllerProvider(request),
            (previous, next) {},
          );
          var session = await container.read(
            quizControllerProvider(request).future,
          );
          final notifier = container.read(
            quizControllerProvider(request).notifier,
          );
          final answers = finish ? session.questions.length : 1;
          for (var i = 0; i < answers; i++) {
            final question = session.questions[i] as McqQuestion;
            await notifier.submitAnswer(
              McqAnswer(
                questionId: question.id,
                selectedOptionId: question.options.first.id,
              ),
            );
            session = container
                .read(quizControllerProvider(request))
                .requireValue;
          }
          if (finish) {
            expect(session.result, isNotNull);
            // Extra callbacks after the result must not count again.
            await notifier.submitAnswer(
              McqAnswer(
                questionId: session.questions.first.id,
                selectedOptionId: 'x',
              ),
            );
          }
          sub.close();
          await container.pump();
        }

        expect(container.read(rewardsProvider).chestProgress, 0);
        await play(finish: false); // abandoned
        expect(container.read(rewardsProvider).chestProgress, 0);
        await play(finish: true);
        expect(container.read(rewardsProvider).chestProgress, 1);
        await play(finish: true);
        expect(container.read(rewardsProvider).chestProgress, 2);
      },
    );
  });
}

class _SpyRandom extends FixedRandom {
  final void Function(int max) onAsk;
  _SpyRandom(this.onAsk) : super(0);
  @override
  int nextInt(int max) {
    onAsk(max);
    return 0;
  }
}
