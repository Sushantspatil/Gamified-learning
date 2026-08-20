import '../models/daily_reward_model.dart';

/// Implemented today by [DailyRewardMockDatasource]. Swap for a
/// Firestore-backed implementation later.
abstract class DailyRewardDatasource {
  Future<DailyRewardModel> getTodayReward(String userId, int streakDay);

  Future<DailyRewardModel> claimTodayReward(String userId, int streakDay);
}
