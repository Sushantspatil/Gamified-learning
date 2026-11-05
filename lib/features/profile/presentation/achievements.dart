import 'package:flutter/material.dart';

/// What the badges are worked out from. All of it is already on the phone.
class AchievementInputs {
  /// Games finished (the rewards system remembers the most recent hundred).
  final int gamesPlayed;
  final int streak;
  final int level;

  /// Whether the daily spin has ever been used.
  final bool hasSpun;

  /// Avatars and frames owned.
  final int cosmeticsOwned;

  const AchievementInputs({
    this.gamesPlayed = 0,
    this.streak = 0,
    this.level = 1,
    this.hasSpun = false,
    this.cosmeticsOwned = 0,
  });
}

/// One badge: what it is for, and how far along you are.
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int current;
  final int target;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.current,
    required this.target,
  });

  bool get unlocked => current >= target;

  /// 0..1, for the little bar on a locked badge.
  double get progress => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);

  /// "3 / 7", never past the target.
  String get progressLabel => '${current.clamp(0, target)} / $target';
}

/// The full list, in the order the badges are shown.
List<Achievement> computeAchievements(AchievementInputs i) {
  const green = Color(0xFF2EB67D);
  const orange = Color(0xFFFF8A1F);
  const purple = Color(0xFF6D5DFE);
  const gold = Color(0xFFFFB82E);
  const cyan = Color(0xFF00B8D9);
  const pink = Color(0xFFE056A0);

  return [
    Achievement(
      id: 'first_game',
      title: 'First Steps',
      description: 'Finish your first game.',
      icon: Icons.flag_rounded,
      color: green,
      current: i.gamesPlayed,
      target: 1,
    ),
    Achievement(
      id: 'ten_games',
      title: 'Getting Warm',
      description: 'Finish 10 games.',
      icon: Icons.local_fire_department_rounded,
      color: orange,
      current: i.gamesPlayed,
      target: 10,
    ),
    Achievement(
      id: 'fifty_games',
      title: 'Dedicated',
      description: 'Finish 50 games.',
      icon: Icons.military_tech_rounded,
      color: purple,
      current: i.gamesPlayed,
      target: 50,
    ),
    Achievement(
      id: 'streak_3',
      title: 'On Fire',
      description: 'Play 3 days in a row.',
      icon: Icons.whatshot_rounded,
      color: orange,
      current: i.streak,
      target: 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Play 7 days in a row.',
      icon: Icons.calendar_month_rounded,
      color: gold,
      current: i.streak,
      target: 7,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Unstoppable',
      description: 'Play 30 days in a row.',
      icon: Icons.bolt_rounded,
      color: pink,
      current: i.streak,
      target: 30,
    ),
    Achievement(
      id: 'level_5',
      title: 'Level Up',
      description: 'Reach level 5.',
      icon: Icons.trending_up_rounded,
      color: cyan,
      current: i.level,
      target: 5,
    ),
    Achievement(
      id: 'level_10',
      title: 'Rising Star',
      description: 'Reach level 10.',
      icon: Icons.star_rounded,
      color: gold,
      current: i.level,
      target: 10,
    ),
    Achievement(
      id: 'first_spin',
      title: 'Lucky Spin',
      description: 'Use your daily spin.',
      icon: Icons.casino_rounded,
      color: pink,
      current: i.hasSpun ? 1 : 0,
      target: 1,
    ),
    Achievement(
      id: 'first_cosmetic',
      title: 'Collector',
      description: 'Own an avatar or a frame.',
      icon: Icons.checkroom_rounded,
      color: purple,
      current: i.cosmeticsOwned,
      target: 1,
    ),
    Achievement(
      id: 'three_cosmetics',
      title: 'Fashionista',
      description: 'Own 3 avatars or frames.',
      icon: Icons.auto_awesome_rounded,
      color: cyan,
      current: i.cosmeticsOwned,
      target: 3,
    ),
  ];
}
