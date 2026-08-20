/// Placeholder quiz-points-to-reward conversion — not specified by the
/// product requirements. Operates on primitive ints (not quiz-feature
/// types) so core/ has no dependency on features/. Once a backend exists,
/// this becomes advisory only — the server must compute the authoritative
/// reward (see Step 10 anti-tampering requirements).
class RewardCalculator {
  RewardCalculator._();

  static ({int xp, int coins}) forEarnedPoints(int earnedPoints) {
    return (xp: earnedPoints, coins: (earnedPoints / 2).round());
  }
}
