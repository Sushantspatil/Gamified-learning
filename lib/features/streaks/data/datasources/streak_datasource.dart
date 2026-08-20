import '../models/streak_model.dart';

/// Implemented today by [StreakMockDatasource]. Swap for a Firestore-backed
/// implementation later — streak counts must eventually be server-verified
/// too, since they gate daily-reward payouts (Step 10).
abstract class StreakDatasource {
  Future<StreakModel> getStreak(String userId);

  Future<StreakModel> recordAppOpen(String userId);
}
