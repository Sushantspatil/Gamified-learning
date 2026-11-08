import 'package:equatable/equatable.dart';

/// One streak reward (for example "7 days: 50 coins").
class StreakMilestone extends Equatable {
  final int days;
  final String currency; // 'coins' or 'gems'
  final int reward;
  final bool reached;
  final bool claimed;

  const StreakMilestone({
    required this.days,
    required this.currency,
    required this.reward,
    required this.reached,
    required this.claimed,
  });

  bool get canClaim => reached && !claimed;

  /// e.g. "+50 coins".
  String get rewardLabel => '+$reward $currency';

  @override
  List<Object?> get props => [days, currency, reward, reached, claimed];
}

/// The player's streak rewards, from the backend's `GET /streak`.
class StreakRewards extends Equatable {
  final int currentStreak;
  final List<StreakMilestone> milestones;

  /// Streak freezes: protect a missed day, bought with gems. When
  /// [freezesEnabled] is false the server cannot sell them yet, so the app
  /// shows nothing about them.
  final bool freezesEnabled;
  final int freezes;
  final int maxFreezes;
  final int freezePriceGems;

  const StreakRewards({
    required this.currentStreak,
    required this.milestones,
    this.freezesEnabled = false,
    this.freezes = 0,
    this.maxFreezes = 0,
    this.freezePriceGems = 0,
  });

  bool get canBuyFreeze => freezesEnabled && freezes < maxFreezes;

  /// The first reward that is ready to collect, if any.
  StreakMilestone? get claimable {
    for (final m in milestones) {
      if (m.canClaim) return m;
    }
    return null;
  }

  /// The next reward the streak has not reached yet, if any.
  StreakMilestone? get next {
    for (final m in milestones) {
      if (!m.reached) return m;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    currentStreak,
    milestones,
    freezesEnabled,
    freezes,
    maxFreezes,
    freezePriceGems,
  ];
}
