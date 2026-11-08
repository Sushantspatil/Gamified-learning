import '../../domain/entities/daily_mission.dart';

class DailyMissionModel extends DailyMission {
  const DailyMissionModel({
    required super.id,
    required super.title,
    required super.targetCount,
    required super.progressCount,
    required super.coinReward,
    super.currency,
    super.claimed,
  });

  /// One goal from `GET /daily-goals`. Returns null for a row that is missing
  /// what the card needs, so one bad row cannot hide the others.
  static DailyMissionModel? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    final target = json['target'];
    final progress = json['progress'];
    final reward = json['reward'];
    if (id is! String || title is! String) return null;
    if (target is! num || progress is! num || reward is! num) return null;
    final currency = json['currency'] == 'gems' ? 'gems' : 'coins';
    return DailyMissionModel(
      id: id,
      title: title,
      targetCount: target.toInt(),
      progressCount: progress.toInt(),
      coinReward: reward.toInt(),
      currency: currency,
      claimed: json['claimed'] == true,
    );
  }
}
