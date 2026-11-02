import 'package:flutter/material.dart';

/// Frontend-only rewards: one currency (coins), stored on this device.

enum PowerUpType { hint, retry, fiftyFifty }

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

  /// Quizzes completed towards the current chest, 0..[chestTarget].
  final int chestProgress;

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
    this.processedQuizIds = const [],
    this.ownedAvatars = const {},
    this.ownedFrames = const {},
    this.equippedAvatar,
    this.equippedFrame,
    this.powerUps = const {},
  });

  static const int chestTarget = 3;
  static const int chestReward = 50;
  static const int startingCoins = 100;

  bool get chestReady => chestProgress >= chestTarget;

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
      processedQuizIds: processedQuizIds ?? this.processedQuizIds,
      ownedAvatars: ownedAvatars ?? this.ownedAvatars,
      ownedFrames: ownedFrames ?? this.ownedFrames,
      equippedAvatar: equippedAvatar ?? this.equippedAvatar,
      equippedFrame: equippedFrame ?? this.equippedFrame,
      powerUps: powerUps ?? this.powerUps,
    );
  }
}
