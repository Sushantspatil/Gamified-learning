import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_key.dart';
import '../../data/rewards_mock_data.dart';
import '../../domain/rewards_models.dart';

/// Injectable so tests control "today" and the spin outcome.
final rewardsClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final rewardsRandomProvider = Provider<Random>((ref) => Random());

@immutable
class RewardsState {
  final int coins;
  final int xp;
  final String? lastSpinDateKey;

  /// Set between the wheel starting and the reveal; the prize is credited
  /// when the spin completes, not before.
  final String? pendingSpinSegmentId;
  final List<SpinHistoryEntry> spinHistory;
  final Set<String> ownedItemIds;
  final String? equippedAvatarId;
  final String? equippedFrameId;
  final Map<PowerUpType, int> powerUps;
  final Map<ChestTier, int> chestProgress;
  final Set<ChestTier> claimedChests;

  const RewardsState({
    required this.coins,
    required this.xp,
    required this.lastSpinDateKey,
    required this.pendingSpinSegmentId,
    required this.spinHistory,
    required this.ownedItemIds,
    required this.equippedAvatarId,
    required this.equippedFrameId,
    required this.powerUps,
    required this.chestProgress,
    required this.claimedChests,
  });

  bool isSpinAvailableOn(DateTime now) => lastSpinDateKey != dateKey(now);

  int powerUpCount(PowerUpType type) => powerUps[type] ?? 0;

  int progressOf(ChestTier tier) => chestProgress[tier] ?? 0;

  ChestStatus chestStatus(ChestDefinition chest) {
    if (claimedChests.contains(chest.tier)) return ChestStatus.claimed;
    final progress = progressOf(chest.tier);
    if (progress >= chest.target) return ChestStatus.ready;
    if (progress == 0) return ChestStatus.locked;
    return ChestStatus.inProgress;
  }

  /// Chests that can be opened right now.
  int get readyChestCount => RewardsMockData.chests
      .where((chest) => chestStatus(chest) == ChestStatus.ready)
      .length;

  RewardsState copyWith({
    int? coins,
    int? xp,
    String? lastSpinDateKey,
    String? pendingSpinSegmentId,
    bool clearPendingSpin = false,
    List<SpinHistoryEntry>? spinHistory,
    Set<String>? ownedItemIds,
    String? equippedAvatarId,
    String? equippedFrameId,
    Map<PowerUpType, int>? powerUps,
    Map<ChestTier, int>? chestProgress,
    Set<ChestTier>? claimedChests,
  }) {
    return RewardsState(
      coins: coins ?? this.coins,
      xp: xp ?? this.xp,
      lastSpinDateKey: lastSpinDateKey ?? this.lastSpinDateKey,
      pendingSpinSegmentId: clearPendingSpin
          ? null
          : pendingSpinSegmentId ?? this.pendingSpinSegmentId,
      spinHistory: spinHistory ?? this.spinHistory,
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
      equippedAvatarId: equippedAvatarId ?? this.equippedAvatarId,
      equippedFrameId: equippedFrameId ?? this.equippedFrameId,
      powerUps: powerUps ?? this.powerUps,
      chestProgress: chestProgress ?? this.chestProgress,
      claimedChests: claimedChests ?? this.claimedChests,
    );
  }
}

/// Single local source of truth for coins, XP, inventory and chest progress
/// used by the wheel, the shop and the chests. Frontend demo only: nothing
/// is persisted or verified by a server, so the "one spin per day" rule is
/// a client-side convenience and not a security control.
class RewardsController extends Notifier<RewardsState> {
  /// Coins handed out instead of a cosmetic the student already owns.
  static const int duplicateItemCoins = 50;

  @override
  RewardsState build() {
    final now = ref.read(rewardsClockProvider)();
    return RewardsState(
      coins: RewardsMockData.startingCoins,
      xp: RewardsMockData.startingXp,
      lastSpinDateKey: null,
      pendingSpinSegmentId: null,
      spinHistory: [
        SpinHistoryEntry(
          title: '20 Coins',
          detail: 'Daily spin',
          icon: Icons.monetization_on_rounded,
          color: RewardsMockData.wheelSegments[1].color,
          at: now.subtract(const Duration(days: 1)),
        ),
        SpinHistoryEntry(
          title: 'Hint Token',
          detail: 'Daily spin',
          icon: Icons.lightbulb_rounded,
          color: RewardsMockData.wheelSegments[3].color,
          at: now.subtract(const Duration(days: 2)),
        ),
      ],
      ownedItemIds: const {},
      equippedAvatarId: null,
      equippedFrameId: null,
      powerUps: const {},
      chestProgress: RewardsMockData.initialChestProgress,
      claimedChests: const {},
    );
  }

  // ---- Spin the wheel -------------------------------------------------

  /// Picks the prize and locks today's spin. Returns the winning index into
  /// [RewardsMockData.wheelSegments], or null if no spin is available. The
  /// wheel animation must land on exactly this index.
  int? startSpin() {
    final now = ref.read(rewardsClockProvider)();
    if (state.pendingSpinSegmentId != null || !state.isSpinAvailableOn(now)) {
      return null;
    }
    final segments = RewardsMockData.wheelSegments;
    final index = ref.read(rewardsRandomProvider).nextInt(segments.length);
    state = state.copyWith(
      lastSpinDateKey: dateKey(now),
      pendingSpinSegmentId: segments[index].id,
    );
    return index;
  }

  /// Credits the pending prize and records it in the history.
  RewardItem? completeSpin() {
    final pendingId = state.pendingSpinSegmentId;
    if (pendingId == null) return null;
    final segment = RewardsMockData.wheelSegments.firstWhere(
      (s) => s.id == pendingId,
    );
    final reward = segment.reward;
    state = _grant(state.copyWith(clearPendingSpin: true), [reward]);
    final entry = SpinHistoryEntry(
      title: segment.shortLabel,
      detail: 'Daily spin',
      icon: reward.icon,
      color: segment.color,
      at: ref.read(rewardsClockProvider)(),
    );
    state = state.copyWith(spinHistory: [entry, ...state.spinHistory]);
    return reward;
  }

  // ---- Shop ------------------------------------------------------------

  PurchaseOutcome purchase(String productId) {
    final product = RewardsMockData.productById(productId);
    if (product == null) return PurchaseOutcome.alreadyOwned;

    if (product.isConsumable) {
      if (state.powerUpCount(product.powerUp!) >= product.maxQuantity) {
        return PurchaseOutcome.maxStack;
      }
    } else if (state.ownedItemIds.contains(product.id)) {
      return PurchaseOutcome.alreadyOwned;
    }
    if (state.coins < product.price) return PurchaseOutcome.insufficientCoins;

    var next = state.copyWith(coins: state.coins - product.price);
    if (product.isConsumable) {
      next = next.copyWith(
        powerUps: {
          ...next.powerUps,
          product.powerUp!: next.powerUpCount(product.powerUp!) + 1,
        },
      );
    } else {
      next = next.copyWith(ownedItemIds: {...next.ownedItemIds, product.id});
    }
    state = next;
    return PurchaseOutcome.success;
  }

  void equip(String productId) {
    final product = RewardsMockData.productById(productId);
    if (product == null ||
        !product.isEquippable ||
        !state.ownedItemIds.contains(productId)) {
      return;
    }
    state = product.category == ShopCategory.avatars
        ? state.copyWith(equippedAvatarId: productId)
        : state.copyWith(equippedFrameId: productId);
  }

  // ---- Chests ----------------------------------------------------------

  /// Opens a ready chest and returns what was actually granted, or null if
  /// the chest is not ready (locked, in progress or already claimed).
  List<RewardItem>? openChest(ChestTier tier) {
    final chest = RewardsMockData.chestFor(tier);
    if (state.chestStatus(chest) != ChestStatus.ready) return null;

    final rewards = <RewardItem>[
      RewardsMockData.coinReward(chest.coins),
      if (chest.bonusPowerUp != null)
        RewardItem(
          kind: RewardKind.powerUp,
          title: 'Hint Token',
          icon: Icons.lightbulb_rounded,
          color: RewardsMockData.hintReward.color,
          powerUp: chest.bonusPowerUp,
        ),
    ];

    final bonusId = chest.bonusShopItemId;
    final bonus = bonusId == null ? null : RewardsMockData.productById(bonusId);
    if (bonus != null) {
      rewards.add(
        state.ownedItemIds.contains(bonus.id)
            ? RewardsMockData.coinReward(duplicateItemCoins)
            : RewardItem(
                kind: RewardKind.shopItem,
                title: bonus.name,
                icon: bonus.icon,
                color: bonus.color,
                shopItemId: bonus.id,
              ),
      );
    }

    state = _grant(
      state.copyWith(claimedChests: {...state.claimedChests, tier}),
      rewards,
    );
    return rewards;
  }

  // ---- Shared ----------------------------------------------------------

  RewardsState _grant(RewardsState from, List<RewardItem> rewards) {
    var next = from;
    for (final reward in rewards) {
      switch (reward.kind) {
        case RewardKind.coins:
          next = next.copyWith(coins: next.coins + reward.amount);
        case RewardKind.xp:
          next = next.copyWith(xp: next.xp + reward.amount);
        case RewardKind.powerUp:
          final type = reward.powerUp!;
          next = next.copyWith(
            powerUps: {
              ...next.powerUps,
              type: next.powerUpCount(type) + reward.amount,
            },
          );
        case RewardKind.shopItem:
          next = next.copyWith(
            ownedItemIds: {...next.ownedItemIds, reward.shopItemId!},
          );
        case RewardKind.chestProgress:
          next = _bumpChestProgress(next);
      }
    }
    return next;
  }

  /// Chest progress goes to the first chest that is not yet full or claimed.
  RewardsState _bumpChestProgress(RewardsState from) {
    for (final chest in RewardsMockData.chests) {
      final progress = from.progressOf(chest.tier);
      if (from.claimedChests.contains(chest.tier) || progress >= chest.target) {
        continue;
      }
      return from.copyWith(
        chestProgress: {...from.chestProgress, chest.tier: progress + 1},
      );
    }
    return from;
  }
}

final rewardsProvider = NotifierProvider<RewardsController, RewardsState>(
  RewardsController.new,
);
