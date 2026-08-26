/// Placeholder XP-to-level curve — not specified by the product requirements.
/// Replace with real game-design numbers when available; every consumer
/// goes through this class so the curve only needs to change in one place.
class LevelCalculator {
  LevelCalculator._();

  static const int xpPerLevel = 100;

  static int levelForXp(int totalXp) => 1 + (totalXp ~/ xpPerLevel);

  static int xpIntoCurrentLevel(int totalXp) => totalXp % xpPerLevel;

  static int xpNeededForNextLevel(int totalXp) =>
      xpPerLevel - xpIntoCurrentLevel(totalXp);
}
