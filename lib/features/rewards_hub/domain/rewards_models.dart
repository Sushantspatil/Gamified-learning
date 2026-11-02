import 'package:flutter/material.dart';

/// Frontend-only demo models shared by Spin the Wheel, the Shop and the
/// Treasure Chests. Nothing here is server-authoritative.

enum PowerUpType { hint, fiftyFifty, retry, streakFreeze }

enum RewardKind { coins, xp, powerUp, chestProgress, shopItem }

/// One thing a student can receive (wheel prize, chest content, ...).
@immutable
class RewardItem {
  final RewardKind kind;
  final int amount;
  final PowerUpType? powerUp;
  final String? shopItemId;
  final String title;
  final IconData icon;
  final Color color;

  const RewardItem({
    required this.kind,
    required this.title,
    required this.icon,
    required this.color,
    this.amount = 1,
    this.powerUp,
    this.shopItemId,
  });

  /// "+30 Coins", "Hint Token", ...
  String get quantityLabel => switch (kind) {
    RewardKind.coins => '+$amount',
    RewardKind.xp => '+$amount XP',
    RewardKind.chestProgress => '+$amount step',
    RewardKind.powerUp => '×$amount',
    RewardKind.shopItem => 'New item',
  };
}

@immutable
class WheelSegment {
  final String id;

  /// Short text drawn on the wheel face.
  final String shortLabel;
  final RewardItem reward;
  final Color color;

  const WheelSegment({
    required this.id,
    required this.shortLabel,
    required this.reward,
    required this.color,
  });
}

@immutable
class SpinHistoryEntry {
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final DateTime at;

  const SpinHistoryEntry({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.at,
  });
}

enum ShopCategory { featured, avatars, frames, powerUps }

@immutable
class ShopProduct {
  final String id;
  final String name;
  final String description;
  final ShopCategory category;
  final int price;
  final IconData icon;
  final Color color;
  final bool featured;
  final PowerUpType? powerUp;

  /// Consumables can be bought repeatedly up to this stack size.
  final int maxQuantity;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.icon,
    required this.color,
    this.featured = false,
    this.powerUp,
    this.maxQuantity = 1,
  });

  bool get isConsumable => powerUp != null;
  bool get isEquippable =>
      category == ShopCategory.avatars || category == ShopCategory.frames;
}

enum ChestTier { bronze, silver, gold }

enum ChestStatus { locked, inProgress, ready, claimed }

@immutable
class ChestDefinition {
  final ChestTier tier;
  final String name;
  final String description;
  final String requirement;
  final int target;
  final Color color;
  final Color colorDark;

  /// Contents are fixed so they stay easy to tweak and the popup always
  /// matches what was granted.
  final int coins;
  final PowerUpType? bonusPowerUp;
  final String? bonusShopItemId;

  const ChestDefinition({
    required this.tier,
    required this.name,
    required this.description,
    required this.requirement,
    required this.target,
    required this.color,
    required this.colorDark,
    required this.coins,
    this.bonusPowerUp,
    this.bonusShopItemId,
  });
}

enum PurchaseOutcome { success, insufficientCoins, alreadyOwned, maxStack }
