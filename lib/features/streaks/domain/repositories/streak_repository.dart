import '../entities/streak.dart';

abstract class StreakRepository {
  Future<Streak> getStreak(String userId);

  /// Idempotent per calendar day: extends the streak if the user was last
  /// active yesterday, resets it to 1 if there was a gap, and is a no-op if
  /// already recorded today.
  Future<Streak> recordAppOpen(String userId);
}
