import '../models/daily_reward_model.dart';

/// The app binds `EmptyDailyRewardDatasource`; tests use a mock from
/// `test/mocks/`.
abstract class DailyRewardDatasource {
  Future<DailyRewardModel> getTodayReward(String userId, int streakDay);

  Future<DailyRewardModel> claimTodayReward(String userId, int streakDay);
}
