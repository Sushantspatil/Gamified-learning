import '../../habit/domain/next_step.dart';

/// Whether a finished game gets a second screen about the player's progress.
///
/// It appears only when something changed that is worth a moment of its own: a
/// level-up, or a daily goal that moved (finished and ready to collect, or one
/// step closer). When every goal is already done and nothing levelled up, there
/// is nothing new to show, so the player goes straight to what is next.
bool resultNeedsProgressBeat({required bool leveledUp, NextStep? step}) =>
    leveledUp ||
    step is CollectGoal ||
    step is CollectStreakReward ||
    step is ContinueGoal;

/// A time as minutes and seconds: "1:42", "0:07", "12:03".
String formatResultTime(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
