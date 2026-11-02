import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/rewards_models.dart';

/// MOCK DATA for the frontend demo. Edit values here to tune the wheel, the
/// shop catalogue and the chests; no other file hard-codes them.
class RewardsMockData {
  RewardsMockData._();

  static const int startingCoins = 500;
  static const int startingXp = 1200;

  static const Color _ink = Color(0xFF1B1B2F);

  static const RewardItem hintReward = RewardItem(
    kind: RewardKind.powerUp,
    title: 'Hint Token',
    icon: Icons.lightbulb_rounded,
    color: AppColors.accentGold,
    powerUp: PowerUpType.hint,
  );

  static RewardItem coinReward(int amount) => RewardItem(
    kind: RewardKind.coins,
    title: 'Coins',
    icon: Icons.monetization_on_rounded,
    color: AppColors.coinGold,
    amount: amount,
  );

  static const List<WheelSegment> wheelSegments = [
    WheelSegment(
      id: 'coins-10',
      shortLabel: '10 Coins',
      color: Color(0xFF6D5DFE),
      reward: RewardItem(
        kind: RewardKind.coins,
        title: 'Coins',
        icon: Icons.monetization_on_rounded,
        color: AppColors.coinGold,
        amount: 10,
      ),
    ),
    WheelSegment(
      id: 'coins-20',
      shortLabel: '20 Coins',
      color: Color(0xFF00B8D9),
      reward: RewardItem(
        kind: RewardKind.coins,
        title: 'Coins',
        icon: Icons.monetization_on_rounded,
        color: AppColors.coinGold,
        amount: 20,
      ),
    ),
    WheelSegment(
      id: 'coins-30',
      shortLabel: '30 Coins',
      color: Color(0xFFFFB82E),
      reward: RewardItem(
        kind: RewardKind.coins,
        title: 'Coins',
        icon: Icons.monetization_on_rounded,
        color: AppColors.coinGold,
        amount: 30,
      ),
    ),
    WheelSegment(
      id: 'hint',
      shortLabel: 'Hint Token',
      color: Color(0xFFE5485E),
      reward: hintReward,
    ),
    WheelSegment(
      id: 'coins-50',
      shortLabel: '50 Coins',
      color: Color(0xFF3D7BFF),
      reward: RewardItem(
        kind: RewardKind.coins,
        title: 'Coins',
        icon: Icons.monetization_on_rounded,
        color: AppColors.coinGold,
        amount: 50,
      ),
    ),
    WheelSegment(
      id: 'xp',
      shortLabel: 'Bonus XP',
      color: Color(0xFFB052FF),
      reward: RewardItem(
        kind: RewardKind.xp,
        title: 'Bonus XP',
        icon: Icons.bolt_rounded,
        color: AppColors.xpPurple,
        amount: 25,
      ),
    ),
    WheelSegment(
      id: 'coins-75',
      shortLabel: '75 Coins',
      color: Color(0xFF2EB67D),
      reward: RewardItem(
        kind: RewardKind.coins,
        title: 'Coins',
        icon: Icons.monetization_on_rounded,
        color: AppColors.coinGold,
        amount: 75,
      ),
    ),
    WheelSegment(
      id: 'chest',
      shortLabel: 'Chest +1',
      color: Color(0xFFFF7A1A),
      reward: RewardItem(
        kind: RewardKind.chestProgress,
        title: 'Chest Progress',
        icon: Icons.inventory_2_rounded,
        color: AppColors.streakFire,
      ),
    ),
  ];

  /// Whether a wheel face colour needs dark text to stay readable.
  static Color labelColorFor(Color background) =>
      background.computeLuminance() > 0.5 ? _ink : Colors.white;

  static const List<ShopProduct> shopProducts = [
    // Avatars
    ShopProduct(
      id: 'avatar-scholar',
      name: 'Scholar Avatar',
      description: 'A graduate cap and a head full of ideas.',
      category: ShopCategory.avatars,
      price: 200,
      icon: Icons.school_rounded,
      color: Color(0xFF6D5DFE),
      featured: true,
    ),
    ShopProduct(
      id: 'avatar-explorer',
      name: 'Explorer Avatar',
      description: 'For learners who chase every new topic.',
      category: ShopCategory.avatars,
      price: 250,
      icon: Icons.explore_rounded,
      color: Color(0xFF00B8D9),
    ),
    ShopProduct(
      id: 'avatar-wizard',
      name: 'Wizard Avatar',
      description: 'Turn tricky ledgers into magic.',
      category: ShopCategory.avatars,
      price: 350,
      icon: Icons.auto_fix_high_rounded,
      color: Color(0xFFB052FF),
    ),
    ShopProduct(
      id: 'avatar-robot',
      name: 'Robo Avatar',
      description: 'Calculates every balance sheet in a blink.',
      category: ShopCategory.avatars,
      price: 300,
      icon: Icons.smart_toy_rounded,
      color: Color(0xFF3D7BFF),
    ),
    // Frames
    ShopProduct(
      id: 'frame-golden',
      name: 'Golden Frame',
      description: 'A shining border for top performers.',
      category: ShopCategory.frames,
      price: 150,
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFFB82E),
      featured: true,
    ),
    ShopProduct(
      id: 'frame-silver',
      name: 'Silver Frame',
      description: 'Clean and classy profile border.',
      category: ShopCategory.frames,
      price: 100,
      icon: Icons.military_tech_rounded,
      color: Color(0xFF8FA3BF),
    ),
    ShopProduct(
      id: 'frame-neon',
      name: 'Neon Frame',
      description: 'Glowing edges that stand out.',
      category: ShopCategory.frames,
      price: 180,
      icon: Icons.blur_circular_rounded,
      color: Color(0xFF21E6FF),
    ),
    ShopProduct(
      id: 'frame-royal',
      name: 'Royal Frame',
      description: 'Reserved for true quiz champions.',
      category: ShopCategory.frames,
      price: 300,
      icon: Icons.diamond_rounded,
      color: Color(0xFFE5485E),
    ),
    // Power-ups
    ShopProduct(
      id: 'powerup-hint',
      name: 'Hint Booster',
      description: 'Reveals a helpful clue on one question.',
      category: ShopCategory.powerUps,
      price: 50,
      icon: Icons.lightbulb_rounded,
      color: Color(0xFFFFB82E),
      powerUp: PowerUpType.hint,
      maxQuantity: 9,
    ),
    ShopProduct(
      id: 'powerup-5050',
      name: '50/50 Booster',
      description: 'Removes two wrong options.',
      category: ShopCategory.powerUps,
      price: 100,
      icon: Icons.filter_2_rounded,
      color: Color(0xFF6D5DFE),
      powerUp: PowerUpType.fiftyFifty,
      maxQuantity: 9,
      featured: true,
    ),
    ShopProduct(
      id: 'powerup-retry',
      name: 'Retry Token',
      description: 'Take one more shot at a missed question.',
      category: ShopCategory.powerUps,
      price: 75,
      icon: Icons.replay_rounded,
      color: Color(0xFF2EB67D),
      powerUp: PowerUpType.retry,
      maxQuantity: 9,
    ),
    ShopProduct(
      id: 'powerup-freeze',
      name: 'Streak Freeze',
      description: 'Protects your streak for one missed day.',
      category: ShopCategory.powerUps,
      price: 250,
      icon: Icons.ac_unit_rounded,
      color: Color(0xFF21B6E8),
      powerUp: PowerUpType.streakFreeze,
      maxQuantity: 3,
      featured: true,
    ),
  ];

  static const List<ChestDefinition> chests = [
    ChestDefinition(
      tier: ChestTier.bronze,
      name: 'Bronze Chest',
      description: 'A small reward for staying on top of your daily goals.',
      requirement: 'Complete 3 daily missions',
      target: 3,
      color: Color(0xFFCD7F32),
      colorDark: Color(0xFF7A4A1C),
      coins: 60,
      bonusPowerUp: PowerUpType.hint,
    ),
    ChestDefinition(
      tier: ChestTier.silver,
      name: 'Silver Chest',
      description: 'Earned by hitting your weekly learning target.',
      requirement: 'Complete 5 lessons this week',
      target: 5,
      color: Color(0xFFA9B8CC),
      colorDark: Color(0xFF5E6E85),
      coins: 150,
      bonusShopItemId: 'frame-silver',
    ),
    ChestDefinition(
      tier: ChestTier.gold,
      name: 'Golden Chest',
      description: 'The big prize for finishing a chapter milestone.',
      requirement: 'Finish 4 topics in a chapter',
      target: 4,
      color: Color(0xFFFFB82E),
      colorDark: Color(0xFFB27A00),
      coins: 300,
      bonusShopItemId: 'avatar-wizard',
    ),
  ];

  /// Starting progress for the demo.
  static const Map<ChestTier, int> initialChestProgress = {
    ChestTier.bronze: 2,
    ChestTier.silver: 3,
    ChestTier.gold: 0,
  };

  static ShopProduct? productById(String id) {
    for (final product in shopProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  static ChestDefinition chestFor(ChestTier tier) =>
      chests.firstWhere((chest) => chest.tier == tier);
}
