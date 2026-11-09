import '../../daily_missions/domain/entities/daily_mission.dart';

/// One slice of the daily ring: one goal and how far along it is.
class RingSegment {
  /// 0.0 (not started) to 1.0 (done).
  final double fraction;

  const RingSegment(this.fraction);

  bool get complete => fraction >= 1.0;
}

/// The slices of today's ring, one per goal, in the order the goals come.
List<RingSegment> ringSegments(List<DailyMission> missions) => [
  for (final m in missions)
    RingSegment(
      m.targetCount <= 0
          ? 1.0
          : (m.progressCount / m.targetCount).clamp(0.0, 1.0).toDouble(),
    ),
];

/// How many goals are finished.
int ringDone(List<RingSegment> segments) =>
    segments.where((s) => s.complete).length;
