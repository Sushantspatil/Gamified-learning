import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_providers.dart';
import '../../../core/audio/game_sound.dart';
import '../../daily_missions/presentation/providers/daily_mission_providers.dart';
import '../../streaks/presentation/providers/streak_rewards_providers.dart';
import '../domain/next_step.dart';

/// The current next step, or null while there is nothing to show. It follows the
/// daily goals and streak rewards, so it updates the moment a game finishes or a
/// reward is collected.
final nextStepProvider = Provider<NextStep?>((ref) {
  final missions = ref.watch(dailyMissionsControllerProvider).valueOrNull;
  final rewards = ref.watch(streakRewardsControllerProvider).valueOrNull;
  return decideNextStep(missions: missions ?? const [], streakRewards: rewards);
});

/// What a "Collect" step pays, e.g. "+20 coins". Null for steps that pay nothing.
String? rewardLabelOf(NextStep step) => switch (step) {
  CollectGoal(:final mission) => mission.rewardLabel,
  CollectStreakReward(:final milestone) => milestone.rewardLabel,
  _ => null,
};

/// Collects the reward of a "Collect" step and celebrates it with a sound and a
/// buzz. Returns null on success, or a short message to show the player.
Future<String?> collectNextStep(WidgetRef ref, NextStep step) async {
  final String? problem = switch (step) {
    CollectGoal(:final mission) =>
      await ref
          .read(dailyMissionsControllerProvider.notifier)
          .claim(mission.id),
    CollectStreakReward(:final milestone) =>
      await ref
          .read(streakRewardsControllerProvider.notifier)
          .claim(milestone.days),
    _ => null,
  };
  if (problem == null) {
    // Best effort: a phone without audio or haptics must not break collecting.
    try {
      ref.read(gameAudioServiceProvider).play(GameSound.coinReward);
      unawaited(HapticFeedback.mediumImpact());
    } catch (_) {}
  }
  return problem;
}
