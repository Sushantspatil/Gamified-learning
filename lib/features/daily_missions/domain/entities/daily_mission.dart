import 'package:equatable/equatable.dart';

class DailyMission extends Equatable {
  final String id;
  final String title;
  final int targetCount;
  final int progressCount;

  /// The reward amount (named for coins, which most goals pay).
  final int coinReward;

  /// What the reward is paid in: 'coins' or 'gems'.
  final String currency;

  /// The reward was already collected today.
  final bool claimed;

  const DailyMission({
    required this.id,
    required this.title,
    required this.targetCount,
    required this.progressCount,
    required this.coinReward,
    this.currency = 'coins',
    this.claimed = false,
  });

  bool get isCompleted => progressCount >= targetCount;

  /// Done, and the reward is waiting to be collected.
  bool get canClaim => isCompleted && !claimed;

  /// e.g. "+20 coins" or "+2 gems".
  String get rewardLabel => '+$coinReward $currency';

  @override
  List<Object?> get props => [
    id,
    title,
    targetCount,
    progressCount,
    coinReward,
    currency,
    claimed,
  ];
}
