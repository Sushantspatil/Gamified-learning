import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/backend_topic_mapper.dart';
import '../../../questions/domain/entities/question.dart';

/// Models whether a specific game mode is enabled for a given topic
/// and what reason to show if disabled.
class GameModeAvailability {
  final QuestionType mode;
  final bool isEnabled;
  final String? reason;

  const GameModeAvailability({
    required this.mode,
    required this.isEnabled,
    this.reason,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameModeAvailability &&
        other.mode == mode &&
        other.isEnabled == isEnabled &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(mode, isEnabled, reason);

  @override
  String toString() =>
      'GameModeAvailability(mode: ${mode.backendGameMode}, isEnabled: $isEnabled, reason: $reason)';
}

const practicePlayableModes = [
  QuestionType.mcq,
  QuestionType.matchTheFollowing,
  QuestionType.sortItRight,
  QuestionType.suddenDeath,
];

/// Evaluates availability for all game modes on a given [topicId].
///
/// NOTE on Multi-Mode Availability Architecture:
/// The generic backend endpoint `GET /api/v1/topics/:topic_id/questions` MUST NOT
/// be used as the authority for multi-mode availability. That endpoint only fetches
/// MCQ questions. Sort It Out, Match the Following, and Sudden Death have separate
/// session creation and dataset flows on the backend.
///
/// In the current release, backend data is seeded with playable questions for all
/// four modes under Accounting (`accounting`) and Mental Maths (`mental-maths-*`).
///
/// When the backend introduces a dedicated mode availability endpoint (e.g.
/// `GET /topics/:topic/availability` or `GET /topics/:topic/game-modes`), this provider
/// can asynchronously query that endpoint while keeping the UI and game screens unchanged.
final gameModeAvailabilityProvider =
    Provider.family<Map<QuestionType, GameModeAvailability>, String?>((
  ref,
  topicId,
) {
  if (topicId == null || topicId.trim().isEmpty) {
    return {
      for (final mode in practicePlayableModes)
        mode: GameModeAvailability(
          mode: mode,
          isEnabled: false,
          reason: 'Select a topic first',
        ),
    };
  }

  // Backend subjects seeded for all 4 game modes (MCQ, Sudden Death, Sort It Out,
  // Match the Following): Accounts and Mental Maths.
  final isSupported = isBackendPlayableTopic(topicId);

  return {
    for (final mode in practicePlayableModes)
      mode: GameModeAvailability(
        mode: mode,
        isEnabled: isSupported,
        reason: isSupported ? null : 'Not available for this topic yet',
      ),
  };
});
