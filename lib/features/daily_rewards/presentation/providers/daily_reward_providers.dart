import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/daily_reward_datasource.dart';
import '../../data/datasources/mock/daily_reward_mock_datasource.dart';
import '../../data/repositories/daily_reward_repository_impl.dart';
import '../../domain/entities/daily_reward.dart';
import '../../domain/repositories/daily_reward_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed DailyRewardDatasource
/// implementation when the backend is ready.
final dailyRewardDatasourceProvider = Provider<DailyRewardDatasource>((ref) {
  return DailyRewardMockDatasource();
});

final dailyRewardRepositoryProvider = Provider<DailyRewardRepository>((ref) {
  return DailyRewardRepositoryImpl(ref.watch(dailyRewardDatasourceProvider));
});

class DailyRewardController extends AsyncNotifier<DailyReward?> {
  @override
  Future<DailyReward?> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return null;

    final streak = await ref.watch(streakControllerProvider.future);
    final cycleDay = streak.currentStreak < 1 ? 1 : streak.currentStreak;
    return ref.watch(dailyRewardRepositoryProvider).getTodayReward(user.id, cycleDay);
  }

  Future<void> claim() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    final streak = ref.read(streakControllerProvider).valueOrNull;
    if (user == null || streak == null) return;

    final cycleDay = streak.currentStreak < 1 ? 1 : streak.currentStreak;

    state = const AsyncValue<DailyReward?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(dailyRewardRepositoryProvider).claimTodayReward(user.id, cycleDay),
    );

    final claimed = state.valueOrNull;
    if (claimed != null) {
      await ref.read(walletControllerProvider.notifier).credit(
            currency: CurrencyType.coins,
            amount: claimed.coins,
            reason: 'Daily reward',
          );
    }
  }
}

final dailyRewardControllerProvider = AsyncNotifierProvider<DailyRewardController, DailyReward?>(
  DailyRewardController.new,
);
