import '../../domain/entities/leaderboard_filter.dart';
import '../models/leaderboard_entry_model.dart';
import '../models/leaderboard_response_model.dart';

abstract class LeaderboardDatasource {
  Future<LeaderboardResponseModel> getLeaderboardPage({
    required LeaderboardFilter filter,
    int page = 1,
    int pageSize = 50,
  });

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
