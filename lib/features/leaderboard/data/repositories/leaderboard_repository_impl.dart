import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardDatasource _datasource;

  LeaderboardRepositoryImpl(this._datasource);

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
}
