import 'package:flutter/material.dart';

/// Frontend-only rewards: coins and gems, stored on this device.

enum PowerUpType { hint, retry, fiftyFifty }

/// The three chests, in the order they unlock during one cycle of games.
/// [unlockAt] is the number of finished games in the cycle that earns the
/// chest; [forcePrice] is what it costs in coins to open it right away.
enum ChestTier {
  golden(unlockAt: 3, forcePrice: 200),
  cyber(unlockAt: 6, forcePrice: 500),
  galaxy(unlockAt: 10, forcePrice: 1000);

  final int unlockAt;
  final int forcePrice;

  const ChestTier({required this.unlockAt, required this.forcePrice});
}

/// What a chest paid out. Exactly one of the three kinds is set.
@immutable
class ChestReward {
  final ChestTier tier;
  final int coins;
  final int gems;

  /// A cosmetic (avatar or frame) that is now owned.
  final ShopProduct? cosmetic;

  const ChestReward({
    required this.tier,
    this.coins = 0,
    this.gems = 0,
    this.cosmetic,
  });
}

enum ChestOpenStatus {
  opened,

  /// Forcing a chest open without enough coins.
  notEnoughCoins,

  /// Forcing a chest open that has already been earned (open it for free).
  alreadyEarned,

  /// Opening a chest that has not been earned.
  notEarned,
}

@immutable
class ChestOpenResult {
  final ChestOpenStatus status;
  final ChestReward? reward;

  const ChestOpenResult(this.status, [this.reward]);

  bool get opened => status == ChestOpenStatus.opened;
}

enum ProductKind { avatar, frame, powerUp }

enum PurchaseOutcome { success, notEnoughCoins, alreadyOwned, unavailable }

@immutable
class WheelSegment {
  final int coins;
  final Color color;

  const WheelSegment({required this.coins, required this.color});
}

@immutable
class ShopProduct {
  final String id;
  final String name;
  final int price;
  final ProductKind kind;
  final IconData icon;
  final Color color;
  final PowerUpType? powerUp;

  /// Listed in the shop but cannot be bought yet because no quiz flow can use it.
  final bool comingSoon;
  final String? description;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.kind,
    required this.icon,
    required this.color,
    this.powerUp,
    this.comingSoon = false,
    this.description,
  });
}

@immutable
class RewardsState {
  final int coins;

  /// Local calendar day of the last spin, as yyyy-MM-dd.
  final String? lastSpinDate;
  final int? lastSpinReward;

  /// Prize chosen at the start of a spin and credited when the wheel stops
  /// (or on next launch if the app was closed mid-spin).
  final int? pendingSpinReward;

  /// Games finished in the current chest cycle, 0..[chestCycle]-1. The cycle
  /// restarts at 0 when the last chest of the cycle is earned.
  final int chestProgress;

  /// Chests earned and waiting to be opened (they are never lost).
  final Map<ChestTier, int> chestsReady;

  /// Second currency, paid by the Galaxy chest.
  final int gems;

  /// Quiz attempts already counted (most recent kept) so none counts twice.
  final List<String> processedQuizIds;
  final Set<String> ownedAvatars;
  final Set<String> ownedFrames;
  final String? equippedAvatar;
  final String? equippedFrame;
  final Map<PowerUpType, int> powerUps;

  const RewardsState({
    required this.coins,
    this.lastSpinDate,
    this.lastSpinReward,
    this.pendingSpinReward,
    this.chestProgress = 0,
    this.chestsReady = const {},
    this.gems = 0,
    this.processedQuizIds = const [],
    this.ownedAvatars = const {},
    this.ownedFrames = const {},
    this.equippedAvatar,
    this.equippedFrame,
    this.powerUps = const {},
  });

  /// Games in one full chest cycle (the last chest's milestone).
  static const int chestCycle = 10;
  static const int startingCoins = 100;

  int chestsReadyCount(ChestTier tier) => chestsReady[tier] ?? 0;

  bool chestReady(ChestTier tier) => chestsReadyCount(tier) > 0;

  bool get anyChestReady => ChestTier.values.any(chestReady);

  /// Games still to finish before [tier] is earned again. When this cycle has
  /// already passed the chest's milestone, it counts into the next cycle.
  int gamesUntil(ChestTier tier) => chestProgress < tier.unlockAt
      ? tier.unlockAt - chestProgress
      : chestCycle - chestProgress + tier.unlockAt;

  int powerUpCount(PowerUpType type) => powerUps[type] ?? 0;

  /// One free spin per local calendar day (a date in the future counts as
  /// used, so winding the clock back does not hand out extra spins).
  bool canSpinOn(String todayKey) =>
      lastSpinDate == null || todayKey.compareTo(lastSpinDate!) > 0;

  RewardsState copyWith({
    int? coins,
    String? lastSpinDate,
    int? lastSpinReward,
    int? pendingSpinReward,
    bool clearPendingSpin = false,
    int? chestProgress,
    Map<ChestTier, int>? chestsReady,
    int? gems,
    List<String>? processedQuizIds,
    Set<String>? ownedAvatars,
    Set<String>? ownedFrames,
    String? equippedAvatar,
    String? equippedFrame,
    Map<PowerUpType, int>? powerUps,
  }) {
    return RewardsState(
      coins: coins ?? this.coins,
      lastSpinDate: lastSpinDate ?? this.lastSpinDate,
      lastSpinReward: lastSpinReward ?? this.lastSpinReward,
      pendingSpinReward: clearPendingSpin
          ? null
          : pendingSpinReward ?? this.pendingSpinReward,
      chestProgress: chestProgress ?? this.chestProgress,
      chestsReady: chestsReady ?? this.chestsReady,
      gems: gems ?? this.gems,
      processedQuizIds: processedQuizIds ?? this.processedQuizIds,
      ownedAvatars: ownedAvatars ?? this.ownedAvatars,
      ownedFrames: ownedFrames ?? this.ownedFrames,
      equippedAvatar: equippedAvatar ?? this.equippedAvatar,
      equippedFrame: equippedFrame ?? this.equippedFrame,
      powerUps: powerUps ?? this.powerUps,
    );
  }
}
