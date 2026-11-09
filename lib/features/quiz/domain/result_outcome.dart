/// How a finished game is greeted: a short headline for how it went, an optional
/// line under it, and whether it was a poor game (so the screen is calmer and the
/// mascot sympathetic). The same rules serve every game mode.
class ResultOutcome {
  /// "Brilliant!", "Great job!"... shown big at the top.
  final String headline;

  /// A short line under the headline, or null.
  final String? detail;

  /// Whether the game was a poor one (nothing right, or it ended with nothing).
  final bool subdued;

  const ResultOutcome({
    required this.headline,
    this.detail,
    this.subdued = false,
  });
}

/// Decides the greeting.
///
/// [endedEarly] is a Sudden Death run: it has no fixed length, so the headline
/// follows how many answers were right in a row.
ResultOutcome outcomeFor({
  required bool endedEarly,
  required int correct,
  required int total,
}) {
  if (endedEarly) {
    final headline = switch (correct) {
      0 => 'Tough one!',
      < 5 => 'Good try!',
      < 10 => 'Nice run!',
      _ => 'Incredible run!',
    };
    return ResultOutcome(
      headline: headline,
      detail: correct == 0
          ? 'The first one got you. Go again!'
          : 'You got $correct right before it ended',
      subdued: correct == 0,
    );
  }

  if (total <= 0 || correct <= 0) {
    return const ResultOutcome(
      headline: 'Keep going!',
      detail: 'Every game makes you sharper',
      subdued: true,
    );
  }
  final accuracy = correct / total;
  return ResultOutcome(
    headline: accuracy >= 0.9
        ? 'Brilliant!'
        : accuracy >= 0.6
        ? 'Great job!'
        : 'Good effort!',
  );
}
