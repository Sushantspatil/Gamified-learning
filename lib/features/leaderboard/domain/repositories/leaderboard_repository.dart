import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// A real backend would query a pre-ranked `leaderboard` collection
  /// (Step 12) rather than merging the caller's own claimed XP client-side
  /// — this mock approximates that by taking the current user's XP as a
  /// parameter since there's no server to already know it.
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  });
}
