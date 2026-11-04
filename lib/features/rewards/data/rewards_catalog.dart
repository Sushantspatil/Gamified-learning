import 'package:flutter/material.dart';

import '../domain/rewards_models.dart';

/// The wheel and the shop catalogue. Edit prices and prizes here.
class RewardsCatalog {
  RewardsCatalog._();

  static const Color _red = Color(0xFFB90000);
  static const Color _gold = Color(0xFFFFB900);

  /// Ten equally likely segments (36 degrees each), clockwise from the top.
  /// Red and gold alternate; the prizes are spread so high and low values
  /// are mixed, and the average prize is about 42 coins. Edit the list to
  /// change the prizes: the painter and the spin logic follow it. Keep an
  /// even number of segments so the colours alternate cleanly.
  static const List<WheelSegment> wheel = [
    WheelSegment(coins: 100, color: _red),
    WheelSegment(coins: 15, color: _gold),
    WheelSegment(coins: 50, color: _red),
    WheelSegment(coins: 20, color: _gold),
    WheelSegment(coins: 75, color: _red),
    WheelSegment(coins: 10, color: _gold),
    WheelSegment(coins: 60, color: _red),
    WheelSegment(coins: 25, color: _gold),
    WheelSegment(coins: 40, color: _red),
    WheelSegment(coins: 30, color: _gold),
  ];

  // ---- Chest rewards ------------------------------------------------------
  // Golden pays coins, Cyber a cosmetic, Galaxy gems. Edit the amounts here.

  static const int goldenMinCoins = 40;
  static const int goldenMaxCoins = 100;

  /// Paid by the Cyber chest when every avatar and frame is already owned.
  static const int cyberFallbackCoins = 150;
  static const int galaxyMinGems = 10;
  static const int galaxyMaxGems = 25;

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
