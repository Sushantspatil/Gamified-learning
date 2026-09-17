import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/daily_mission_datasource.dart';
import '../../data/models/daily_mission_model.dart';
import '../../data/repositories/daily_mission_repository_impl.dart';
import '../../domain/entities/daily_mission.dart';
import '../../domain/repositories/daily_mission_repository.dart';

/// Empty binding until the backend exposes daily mission data.
final dailyMissionDatasourceProvider = Provider<DailyMissionDatasource>((ref) {
  return const EmptyDailyMissionDatasource();
});

class EmptyDailyMissionDatasource implements DailyMissionDatasource {
  const EmptyDailyMissionDatasource();

  @override
  Future<List<DailyMissionModel>> getTodayMissions(String userId) async {
    return const [];
  }

  @override
  Future<DailyMissionModel> recordQuizCompleted(String userId) {
    throw UnsupportedError('Daily missions are not available from the backend.');
  }
}

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
