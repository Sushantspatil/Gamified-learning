import '../models/leaderboard_entry_model.dart';
import '../../domain/entities/leaderboard_filter.dart';

/// Implemented today by [LeaderboardMockDatasource]. Swap for a
/// Firestore-backed implementation (leaderboard collection) later.
abstract class LeaderboardDatasource {
  Future<List<LeaderboardEntryModel>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  });

  Future<List<LeaderboardEntryModel>> getLeaderboard({
    required LeaderboardFilter filter,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  });
}
