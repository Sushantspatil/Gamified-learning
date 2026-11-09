/// What a finished game does to the player's best score for its mode.
class BestUpdate {
  /// The score beat an earlier best (a first-ever score is not "a new best":
  /// there was nothing to beat).
  final bool isNewBest;

  /// The best before this game, or null if this is the first scored game.
  final int? previousBest;

  /// The best after this game.
  final int best;

  /// Whether the new best should be written down.
  final bool shouldSave;

  const BestUpdate({
    required this.isNewBest,
    required this.previousBest,
    required this.best,
    required this.shouldSave,
  });
}

BestUpdate updateBest({int? previous, required int score}) {
  if (previous == null) {
    return BestUpdate(
      isNewBest: false,
      previousBest: null,
      best: score,
      // A first game that scored nothing sets no bar to beat.
      shouldSave: score > 0,
    );
  }
  final beaten = score > previous;
  return BestUpdate(
    isNewBest: beaten,
    previousBest: previous,
    best: beaten ? score : previous,
    shouldSave: beaten,
  );
}
