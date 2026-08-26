import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/daily_mission_datasource.dart';
import '../../data/datasources/mock/daily_mission_mock_datasource.dart';
import '../../data/repositories/daily_mission_repository_impl.dart';
import '../../domain/entities/daily_mission.dart';
import '../../domain/repositories/daily_mission_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed DailyMissionDatasource
/// implementation when the backend is ready.
final dailyMissionDatasourceProvider = Provider<DailyMissionDatasource>((ref) {
  return DailyMissionMockDatasource();
});

final dailyMissionRepositoryProvider = Provider<DailyMissionRepository>((ref) {
  return DailyMissionRepositoryImpl(ref.watch(dailyMissionDatasourceProvider));
});

/// Coins for a mission are awarded automatically the moment its progress
/// reaches its target — no separate "claim" step, unlike Daily Rewards.
class DailyMissionsController extends AsyncNotifier<List<DailyMission>> {
  @override
  Future<List<DailyMission>> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return const [];
    return ref.watch(dailyMissionRepositoryProvider).getTodayMissions(user.id);
  }

  Future<void> recordQuizCompletion() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    final before = state.valueOrNull ?? const [];
    final wasCompleted = {for (final m in before) m.id: m.isCompleted};

    final updatedMission = await ref
        .read(dailyMissionRepositoryProvider)
        .recordQuizCompleted(user.id);

    if (updatedMission.isCompleted && wasCompleted[updatedMission.id] != true) {
      await ref
          .read(walletControllerProvider.notifier)
          .credit(
            currency: CurrencyType.coins,
            amount: updatedMission.coinReward,
            reason: 'Mission: ${updatedMission.title}',
          );
    }

    final refreshed = await ref
        .read(dailyMissionRepositoryProvider)
        .getTodayMissions(user.id);
    state = AsyncValue.data(refreshed);
  }
}

final dailyMissionsControllerProvider =
    AsyncNotifierProvider<DailyMissionsController, List<DailyMission>>(
      DailyMissionsController.new,
    );
