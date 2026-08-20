import '../models/daily_mission_model.dart';

/// Implemented today by [DailyMissionMockDatasource]. Swap for a
/// Firestore-backed implementation later.
abstract class DailyMissionDatasource {
  Future<List<DailyMissionModel>> getTodayMissions(String userId);

  Future<DailyMissionModel> recordQuizCompleted(String userId);
}
