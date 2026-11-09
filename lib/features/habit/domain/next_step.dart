import '../../daily_missions/domain/entities/daily_mission.dart';
import '../../streaks/domain/entities/streak_rewards.dart';

/// The one thing the player should do next, chosen from today's goals and the
/// streak rewards. Shown on the home screen and at the end of every game, so the
/// player always sees what is waiting and how close it is.
sealed class NextStep {
  const NextStep();
}

/// A finished goal whose reward is waiting to be collected.
final class CollectGoal extends NextStep {
  final DailyMission mission;

  /// Rewards ready to collect in total (goals and streak), including this one.
  final int readyCount;

  const CollectGoal(this.mission, {required this.readyCount});
}

/// A streak milestone whose reward is waiting to be collected.
final class CollectStreakReward extends NextStep {
  final StreakMilestone milestone;
  final int readyCount;

  const CollectStreakReward(this.milestone, {required this.readyCount});
}

/// A goal in progress: the one that is closest to done.
final class ContinueGoal extends NextStep {
  final DailyMission mission;
  final int goalsDone;
  final int goalsTotal;

  const ContinueGoal(
    this.mission, {
    required this.goalsDone,
    required this.goalsTotal,
  });

  int get remaining => mission.targetCount - mission.progressCount;
}

/// Every goal is done and collected for today.
final class AllGoalsDone extends NextStep {
  /// The next streak reward and how many days away it is, if there is one.
  final StreakMilestone? nextStreakReward;
  final int daysToNextStreakReward;

  const AllGoalsDone({this.nextStreakReward, this.daysToNextStreakReward = 0});
}

/// Picks the next step, or null when there is nothing to show (no goals and no
/// streak rewards from the server).
///
/// Priority: a reward to collect (goals first, then the streak), then the goal
/// closest to done, then "all done".
NextStep? decideNextStep({
  required List<DailyMission> missions,
  StreakRewards? streakRewards,
}) {
  final claimableGoals = missions.where((m) => m.canClaim).toList();
  final streakClaimable = streakRewards?.claimable;
  final readyCount = claimableGoals.length + (streakClaimable == null ? 0 : 1);

  if (claimableGoals.isNotEmpty) {
    return CollectGoal(claimableGoals.first, readyCount: readyCount);
  }
  if (streakClaimable != null) {
    return CollectStreakReward(streakClaimable, readyCount: readyCount);
  }
  if (missions.isEmpty) return null;

  final open = missions.where((m) => !m.isCompleted).toList();
  if (open.isNotEmpty) {
    // The goal needing the fewest more steps; among equals, the smaller goal.
    open.sort((a, b) {
      final byRemaining = (a.targetCount - a.progressCount).compareTo(
        b.targetCount - b.progressCount,
      );
      return byRemaining != 0
          ? byRemaining
          : a.targetCount.compareTo(b.targetCount);
    });
    return ContinueGoal(
      open.first,
      goalsDone: missions.length - open.length,
      goalsTotal: missions.length,
    );
  }

  final next = streakRewards?.next;
  return AllGoalsDone(
    nextStreakReward: next,
    daysToNextStreakReward: next == null
        ? 0
        : next.days - streakRewards!.currentStreak,
  );
}
