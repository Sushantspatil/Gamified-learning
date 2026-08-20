import '../../domain/entities/daily_reward.dart';
import '../../domain/repositories/daily_reward_repository.dart';
import '../datasources/daily_reward_datasource.dart';

class DailyRewardRepositoryImpl implements DailyRewardRepository {
  final DailyRewardDatasource _datasource;

  DailyRewardRepositoryImpl(this._datasource);

  @override
  Future<DailyReward> getTodayReward(String userId, int streakDay) {
    return _datasource.getTodayReward(userId, streakDay);
  }

  @override
  Future<DailyReward> claimTodayReward(String userId, int streakDay) {
    return _datasource.claimTodayReward(userId, streakDay);
  }
}
