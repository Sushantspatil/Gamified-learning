import '../entities/daily_reward.dart';

abstract class DailyRewardRepository {
  Future<DailyReward> getTodayReward(String userId, int streakDay);

  Future<DailyReward> claimTodayReward(String userId, int streakDay);
}
