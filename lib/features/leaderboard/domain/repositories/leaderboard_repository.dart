import '../entities/leaderboard_entry.dart';
import '../entities/leaderboard_filter.dart';
import '../entities/leaderboard_page.dart';

abstract class LeaderboardRepository {
  Future<LeaderboardPage> getLeaderboardPage({
    required LeaderboardFilter filter,
    int page = 1,
    int pageSize = 50,
  });

  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  });

  Future<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardFilter filter,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  });
}
