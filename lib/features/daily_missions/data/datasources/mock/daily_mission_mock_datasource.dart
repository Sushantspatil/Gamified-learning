import '../../../../../core/utils/date_key.dart';
import '../../models/daily_mission_model.dart';
import '../daily_mission_datasource.dart';

const String _completeQuizMissionId = 'complete-1-quiz';

/// MOCK DATA — a single representative mission ("complete 1 quiz today").
/// Replace the binding in daily_mission_providers.dart with a
/// Firestore-backed implementation when the backend is ready; add more
/// missions to the table below as needed.
class DailyMissionMockDatasource implements DailyMissionDatasource {
  final Map<String, String> _lastResetDateKeyByUser = {};
  final Map<String, int> _progressByUser = {};

  void _resetIfNewDay(String userId) {
    final today = dateKey(DateTime.now());
    if (_lastResetDateKeyByUser[userId] != today) {
      _lastResetDateKeyByUser[userId] = today;
      _progressByUser[userId] = 0;
    }
  }

  DailyMissionModel _missionFor(String userId) {
    _resetIfNewDay(userId);
    return DailyMissionModel(
      id: _completeQuizMissionId,
      title: 'Complete 1 quiz today',
      targetCount: 1,
      progressCount: _progressByUser[userId] ?? 0,
      coinReward: 20,
    );
  }

  @override
  Future<List<DailyMissionModel>> getTodayMissions(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [_missionFor(userId)];
  }

  @override
  Future<DailyMissionModel> recordQuizCompleted(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _resetIfNewDay(userId);
    final current = _progressByUser[userId] ?? 0;
    final mission = _missionFor(userId);
    if (current < mission.targetCount) {
      _progressByUser[userId] = current + 1;
    }
    return _missionFor(userId);
  }
}
