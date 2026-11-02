import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/date_key.dart';
import '../data/rewards_catalog.dart';
import '../data/rewards_store.dart';
import '../domain/rewards_models.dart';

/// Injectable so tests control "today" and the spin result.
final rewardsClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final rewardsRandomProvider = Provider<Random>((ref) => Random());

/// The single place that changes coins, spins, chest progress and the
/// inventory. Every change is applied in one synchronous step and then
/// saved, so repeated taps and callbacks cannot double-award or double-buy.
class RewardsController extends Notifier<RewardsState> {
  late RewardsStore _store;

  @override
  RewardsState build() {
    LocalStorageService? storage;
    try {
      storage = ref.read(localStorageServiceProvider);
    } catch (_) {
      storage = null; // not provided (e.g. some tests): keep in memory
    }
    _store = RewardsStore(storage);

    final saved = _store.load();
    var initial =
        saved ?? const RewardsState(coins: RewardsState.startingCoins);

    // The app was closed mid-spin: the prize was already chosen and the
    // day's spin used, so pay it now (exactly once).
    final pending = initial.pendingSpinReward;
    if (pending != null) {
      initial = initial.copyWith(
        coins: initial.coins + pending,
        clearPendingSpin: true,
      );
    }
    if (saved == null || pending != null) _store.save(initial);
    return initial;
  }

  void _commit(RewardsState next) {
    state = next;
    _store.save(next);
  }

  // ---- Spin the Wheel -----------------------------------------------------

  bool canSpinToday() =>
      state.canSpinOn(dateKey(ref.read(rewardsClockProvider)()));

  /// Picks the prize and uses today's spin. Returns the winning index into
  /// [RewardsCatalog.wheel], or null if no spin is available. The wheel must
  /// stop on exactly this segment.
  int? startSpin() {
    final today = dateKey(ref.read(rewardsClockProvider)());
    if (state.pendingSpinReward != null || !state.canSpinOn(today)) return null;
    final index = ref
        .read(rewardsRandomProvider)
        .nextInt(RewardsCatalog.wheel.length);
    final coins = RewardsCatalog.wheel[index].coins;
    _commit(
      state.copyWith(
        lastSpinDate: today,
        lastSpinReward: coins,
        pendingSpinReward: coins,
      ),
    );
    return index;
  }

  /// Credits the pending prize. Returns the coins won, or null if none pending.
  int? completeSpin() {
    final pending = state.pendingSpinReward;
    if (pending == null) return null;
    _commit(
      state.copyWith(coins: state.coins + pending, clearPendingSpin: true),
    );
    return pending;
  }

  // ---- Chest Box ----------------------------------------------------------

  /// Counts one successfully completed quiz attempt. Safe to call repeatedly
  /// with the same [attemptId]. While the chest is full (waiting to be
  /// opened) the attempt is recorded but progress stays at 3/3.
  void recordQuizCompleted(String attemptId) {
    if (state.processedQuizIds.contains(attemptId)) return;
    final ids = [...state.processedQuizIds, attemptId];
    _commit(
      state.copyWith(
        processedQuizIds: ids.length > 100
            ? ids.sublist(ids.length - 100)
            : ids,
        chestProgress: state.chestReady
            ? state.chestProgress
            : state.chestProgress + 1,
      ),
    );
  }

  /// Opens a ready chest: +50 coins and progress back to 0/3.
  bool openChest() {
    if (!state.chestReady) return false;
    _commit(
      state.copyWith(
        coins: state.coins + RewardsState.chestReward,
        chestProgress: 0,
      ),
    );
    return true;
  }

  // ---- Shop ---------------------------------------------------------------

  PurchaseOutcome purchase(String productId) {
    final product = RewardsCatalog.byId(productId);
    if (product == null || product.comingSoon) {
      return PurchaseOutcome.unavailable;
    }
    final owned = switch (product.kind) {
      ProductKind.avatar => state.ownedAvatars.contains(product.id),
      ProductKind.frame => state.ownedFrames.contains(product.id),
      ProductKind.powerUp => false, // consumable: can be bought again
    };
    if (owned) return PurchaseOutcome.alreadyOwned;
    if (state.coins < product.price) return PurchaseOutcome.notEnoughCoins;

    final paid = state.copyWith(coins: state.coins - product.price);
    _commit(switch (product.kind) {
      ProductKind.avatar => paid.copyWith(
        ownedAvatars: {...paid.ownedAvatars, product.id},
      ),
      ProductKind.frame => paid.copyWith(
        ownedFrames: {...paid.ownedFrames, product.id},
      ),
      ProductKind.powerUp => paid.copyWith(
        powerUps: {
          ...paid.powerUps,
          product.powerUp!: paid.powerUpCount(product.powerUp!) + 1,
        },
      ),
    });
    return PurchaseOutcome.success;
  }

  void equip(String productId) {
    final product = RewardsCatalog.byId(productId);
    if (product == null) return;
    if (product.kind == ProductKind.avatar &&
        state.ownedAvatars.contains(productId)) {
      _commit(state.copyWith(equippedAvatar: productId));
    } else if (product.kind == ProductKind.frame &&
        state.ownedFrames.contains(productId)) {
      _commit(state.copyWith(equippedFrame: productId));
    }
  }

  /// Uses one token. Returns false (and changes nothing) with none left.
  bool consumePowerUp(PowerUpType type) {
    final count = state.powerUpCount(type);
    if (count <= 0) return false;
    final next = {...state.powerUps};
    if (count == 1) {
      next.remove(type);
    } else {
      next[type] = count - 1;
    }
    _commit(state.copyWith(powerUps: next));
    return true;
  }
}

final rewardsProvider = NotifierProvider<RewardsController, RewardsState>(
  RewardsController.new,
);
