import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_filter.dart';
import '../../domain/entities/leaderboard_page.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardDatasource _datasource;

  LeaderboardRepositoryImpl(this._datasource);

  @override
  Future<LeaderboardPage> getLeaderboardPage({
    required LeaderboardFilter filter,
    int page = 1,
    int pageSize = 50,
  }) {
    return _datasource.getLeaderboardPage(
      filter: filter,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) {
    return _datasource.getGlobalLeaderboard(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatarId: currentUserAvatarId,
      currentUserXp: currentUserXp,
    );
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardFilter filter,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) {
    return _datasource.getLeaderboard(
      filter: filter,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatarId: currentUserAvatarId,
      currentUserXp: currentUserXp,
    );
  }
}
