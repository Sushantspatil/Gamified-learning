import '../../domain/entities/daily_mission.dart';
import '../../domain/repositories/daily_mission_repository.dart';
import '../datasources/daily_mission_datasource.dart';

class DailyMissionRepositoryImpl implements DailyMissionRepository {
  final DailyMissionDatasource _datasource;

  DailyMissionRepositoryImpl(this._datasource);

  @override
  Future<List<DailyMission>> getTodayMissions(String userId) => _datasource.getTodayMissions(userId);

  @override
  Future<DailyMission> recordQuizCompleted(String userId) => _datasource.recordQuizCompleted(userId);
}
