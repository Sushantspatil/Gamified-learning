import '../../domain/entities/daily_mission.dart';

class DailyMissionModel extends DailyMission {
  const DailyMissionModel({
    required super.id,
    required super.title,
    required super.targetCount,
    required super.progressCount,
    required super.coinReward,
  });
}
