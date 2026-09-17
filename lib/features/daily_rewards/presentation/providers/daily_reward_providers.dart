import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/daily_reward_datasource.dart';
import '../../data/models/daily_reward_model.dart';
import '../../data/repositories/daily_reward_repository_impl.dart';
import '../../domain/entities/daily_reward.dart';
import '../../domain/repositories/daily_reward_repository.dart';

/// Empty binding until the backend exposes daily reward data.
final dailyRewardDatasourceProvider = Provider<DailyRewardDatasource>((ref) {
  return const EmptyDailyRewardDatasource();
});

class EmptyDailyRewardDatasource implements DailyRewardDatasource {
  const EmptyDailyRewardDatasource();

  @override
  Future<DailyRewardModel> getTodayReward(String userId, int streakDay) {
    throw UnsupportedError('Daily rewards are not available from the backend.');
  }

  @override
  Future<DailyRewardModel> claimTodayReward(String userId, int streakDay) {
    throw UnsupportedError('Daily rewards are not available from the backend.');
  }
}

final dailyRewardRepositoryProvider = Provider<DailyRewardRepository>((ref) {
  return DailyRewardRepositoryImpl(ref.watch(dailyRewardDatasourceProvider));
});

class DailyRewardController extends AsyncNotifier<DailyReward?> {
  @override
  Future<DailyReward?> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return null;
    return null;
  }

  Future<void> claim() async {
    state = const AsyncValue.data(null);
  }
}

final dailyRewardControllerProvider =
    AsyncNotifierProvider<DailyRewardController, DailyReward?>(
      DailyRewardController.new,
    );
