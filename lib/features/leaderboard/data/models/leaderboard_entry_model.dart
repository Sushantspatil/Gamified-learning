import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardEntryModel extends LeaderboardEntry {
  const LeaderboardEntryModel({
    required super.rank,
    required super.userId,
    required super.displayName,
    required super.avatarId,
    required super.xp,
    required super.isCurrentUser,
  });
}
