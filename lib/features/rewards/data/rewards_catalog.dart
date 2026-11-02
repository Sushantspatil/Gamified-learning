import 'package:flutter/material.dart';

import '../domain/rewards_models.dart';

/// The wheel and the shop catalogue. Edit prices and prizes here.
class RewardsCatalog {
  RewardsCatalog._();

  /// Six equally likely segments.
  static const List<WheelSegment> wheel = [
    WheelSegment(coins: 10, color: Color(0xFF6D5DFE)),
    WheelSegment(coins: 20, color: Color(0xFF00B8D9)),
    WheelSegment(coins: 30, color: Color(0xFFFFB82E)),
    WheelSegment(coins: 40, color: Color(0xFFE5485E)),
    WheelSegment(coins: 50, color: Color(0xFF2EB67D)),
    WheelSegment(coins: 100, color: Color(0xFFB052FF)),
  ];

  static const List<ShopProduct> avatars = [
    ShopProduct(
      id: 'avatar-scholar',
      name: 'Scholar',
      price: 100,
      kind: ProductKind.avatar,
      icon: Icons.school_rounded,
      color: Color(0xFF6D5DFE),
    ),
    ShopProduct(
      id: 'avatar-explorer',
      name: 'Explorer',
      price: 150,
      kind: ProductKind.avatar,
      icon: Icons.explore_rounded,
      color: Color(0xFF00B8D9),
    ),
    ShopProduct(
      id: 'avatar-champion',
      name: 'Champion',
      price: 200,
      kind: ProductKind.avatar,
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFFFB82E),
    ),
    ShopProduct(
      id: 'avatar-genius',
      name: 'Genius',
      price: 250,
      kind: ProductKind.avatar,
      icon: Icons.psychology_rounded,
      color: Color(0xFFB052FF),
    ),
  ];

  static const List<ShopProduct> frames = [
    ShopProduct(
      id: 'frame-bronze',
      name: 'Bronze Frame',
      price: 50,
      kind: ProductKind.frame,
      icon: Icons.account_circle_rounded,
      color: Color(0xFFCD7F32),
    ),
    ShopProduct(
      id: 'frame-silver',
      name: 'Silver Frame',
      price: 100,
      kind: ProductKind.frame,
      icon: Icons.account_circle_rounded,
      color: Color(0xFFA9B8CC),
    ),
    ShopProduct(
      id: 'frame-gold',
      name: 'Gold Frame',
      price: 150,
      kind: ProductKind.frame,
      icon: Icons.account_circle_rounded,
      color: Color(0xFFFFB82E),
    ),
  ];

  static const List<ShopProduct> powerUps = [
    ShopProduct(
      id: 'powerup-hint',
      name: 'Hint Token',
      price: 50,
      kind: ProductKind.powerUp,
      icon: Icons.lightbulb_rounded,
      color: Color(0xFFFFB82E),
      powerUp: PowerUpType.hint,
      description: 'Shows the hint for one MCQ question.',
    ),
    // Retry needs per-question feedback that MCQ does not have (answers are
    // graded after the last question), so it cannot be used safely yet.
    ShopProduct(
      id: 'powerup-retry',
      name: 'Retry Token',
      price: 75,
      kind: ProductKind.powerUp,
      icon: Icons.replay_rounded,
      color: Color(0xFF2EB67D),
      powerUp: PowerUpType.retry,
      comingSoon: true,
      description: 'Not usable in quizzes yet.',
    ),
    ShopProduct(
      id: 'powerup-5050',
      name: '50/50 Token',
      price: 100,
      kind: ProductKind.powerUp,
      icon: Icons.filter_2_rounded,
      color: Color(0xFF6D5DFE),
      powerUp: PowerUpType.fiftyFifty,
      description: 'Removes two wrong options in one MCQ question.',
    ),
  ];

  static List<ShopProduct> get all => [...avatars, ...frames, ...powerUps];

  static ShopProduct? byId(String id) {
    for (final product in all) {
      if (product.id == id) return product;
    }
    return null;
  }
}
