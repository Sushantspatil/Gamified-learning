import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/daily_mission_datasource.dart';
import '../../data/datasources/remote/daily_mission_remote_datasource.dart';
import '../../data/repositories/daily_mission_repository_impl.dart';
import '../../domain/entities/daily_mission.dart';
import '../../domain/repositories/daily_mission_repository.dart';

/// Today's goals come from the backend (`/daily-goals`).
final dailyMissionDatasourceProvider = Provider<DailyMissionDatasource>((ref) {
  return DailyMissionRemoteDatasource(apiClient: ref.watch(apiClientProvider));
});

final dailyMissionRepositoryProvider = Provider<DailyMissionRepository>((ref) {
  return DailyMissionRepositoryImpl(ref.watch(dailyMissionDatasourceProvider));
});

/// Progress is counted by the server from the player's finished games. A goal's
/// reward is collected with [claim], which the server pays into the account.
class DailyMissionsController extends AsyncNotifier<List<DailyMission>> {
  @override
  Future<List<DailyMission>> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return const [];
    return ref.watch(dailyMissionRepositoryProvider).getTodayMissions(user.id);
  }

  /// Re-reads today's goals (after a game finishes). Keeps the old goals on
  /// screen if the refresh fails.
  Future<void> recordQuizCompletion() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    try {
      final refreshed = await ref
          .read(dailyMissionRepositoryProvider)
          .getTodayMissions(user.id);
      state = AsyncValue.data(refreshed);
    } on AppException {
      // Leave what is shown; the next refresh will catch up.
    }
  }

  /// Collects a finished goal's reward. Returns null on success, or a short
  /// message to show the player. Either way the goals and the balance are
  /// re-read, so "already claimed" simply shows as claimed.
  Future<String?> claim(String missionId) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return 'Sign in to collect rewards.';

    String? problem;
    try {
      await ref
          .read(dailyMissionRepositoryProvider)
          .claimMission(user.id, missionId);
    } on ValidationException catch (e) {
      problem = e.message;
    } on AppException {
      problem = 'Could not collect the reward. Please try again.';
    }

    await recordQuizCompletion();
    // The server paid the account: refresh the balance every screen shows.
    ref.invalidate(walletControllerProvider);
    return problem;
  }
}

final dailyMissionsControllerProvider =
    AsyncNotifierProvider<DailyMissionsController, List<DailyMission>>(
      DailyMissionsController.new,
    );
