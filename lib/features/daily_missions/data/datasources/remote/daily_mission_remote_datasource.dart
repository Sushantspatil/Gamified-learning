import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../models/daily_mission_model.dart';
import '../daily_mission_datasource.dart';

/// Today's goals from the backend (`GET /daily-goals`). Progress is counted by
/// the server from the player's finished games.
class DailyMissionRemoteDatasource implements DailyMissionDatasource {
  final ApiClient _apiClient;

  DailyMissionRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<DailyMissionModel>> getTodayMissions(String userId) async {
    final dynamic data;
    try {
      data = await _apiClient.get(ApiEndpoints.dailyGoals);
    } on NotFoundException {
      // A server without daily goals yet: show no goals instead of an error.
      return const [];
    }
    final goals = data is Map ? data['goals'] : null;
    if (goals is! List) return const [];
    return [for (final goal in goals) ?DailyMissionModel.tryFromJson(goal)];
  }

  @override
  Future<DailyMissionModel> recordQuizCompleted(String userId) {
    // Progress comes from the server; the app only re-reads the goals.
    throw UnsupportedError('Goal progress is counted by the backend.');
  }

  @override
  Future<void> claimMission(String userId, String missionId) async {
    await _apiClient.post(
      ApiEndpoints.dailyGoalsClaim,
      body: {'goal_id': missionId},
    );
  }
}
