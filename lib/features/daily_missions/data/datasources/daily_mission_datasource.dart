import '../models/daily_mission_model.dart';

/// Implemented by [DailyMissionRemoteDatasource] (the backend's daily goals).
abstract class DailyMissionDatasource {
  Future<List<DailyMissionModel>> getTodayMissions(String userId);

  Future<DailyMissionModel> recordQuizCompleted(String userId);

  /// Collects the reward of a finished goal. The account is credited by the
  /// server, so callers refresh the wallet afterwards.
  Future<void> claimMission(String userId, String missionId);
}
