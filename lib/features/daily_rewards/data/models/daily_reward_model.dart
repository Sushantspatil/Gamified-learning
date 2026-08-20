import '../../domain/entities/daily_reward.dart';

class DailyRewardModel extends DailyReward {
  const DailyRewardModel({
    required super.cycleDay,
    required super.coins,
    required super.claimedToday,
  });
}
