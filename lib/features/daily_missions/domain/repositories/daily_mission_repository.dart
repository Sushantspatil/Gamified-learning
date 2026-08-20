import '../entities/daily_mission.dart';

abstract class DailyMissionRepository {
  /// Missions reset daily. Returns today's missions with progress carried
  /// over from earlier today (or a fresh set if this is the first check
  /// today).
  Future<List<DailyMission>> getTodayMissions(String userId);

  /// Increments the "complete a quiz" mission's progress for today.
  Future<DailyMission> recordQuizCompleted(String userId);
}
