import 'package:equatable/equatable.dart';

class DailyMission extends Equatable {
  final String id;
  final String title;
  final int targetCount;
  final int progressCount;
  final int coinReward;

  const DailyMission({
    required this.id,
    required this.title,
    required this.targetCount,
    required this.progressCount,
    required this.coinReward,
  });

  bool get isCompleted => progressCount >= targetCount;

  @override
  List<Object?> get props => [id, title, targetCount, progressCount, coinReward];
}
