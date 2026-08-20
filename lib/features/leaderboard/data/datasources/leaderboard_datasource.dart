import '../models/leaderboard_entry_model.dart';

/// Implemented today by [LeaderboardMockDatasource]. Swap for a
/// Firestore-backed implementation (leaderboard collection) later.
abstract class LeaderboardDatasource {
  Future<List<LeaderboardEntryModel>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  });
}
