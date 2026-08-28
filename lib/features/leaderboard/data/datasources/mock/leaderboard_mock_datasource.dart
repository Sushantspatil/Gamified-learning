import '../../models/leaderboard_entry_model.dart';
import '../../../domain/entities/leaderboard_filter.dart';
import '../leaderboard_datasource.dart';

class _FictionalPlayer {
  final String name;
  final String avatarId;
  final int xp;

  const _FictionalPlayer({
    required this.name,
    required this.avatarId,
    required this.xp,
  });
}

const List<_FictionalPlayer> _fictionalPlayers = [
  _FictionalPlayer(name: 'Grace H.', avatarId: 'owl', xp: 320),
  _FictionalPlayer(name: 'Ada K.', avatarId: 'wizard', xp: 250),
  _FictionalPlayer(name: 'Alan T.', avatarId: 'robot', xp: 180),
  _FictionalPlayer(name: 'Margaret H.', avatarId: 'fox', xp: 140),
  _FictionalPlayer(name: 'Katherine J.', avatarId: 'ninja', xp: 90),
  _FictionalPlayer(name: 'Tim B.', avatarId: 'default', xp: 40),
];

/// MOCK DATA — replace the binding in leaderboard_providers.dart with a
/// Firestore-backed implementation when the backend is ready.
class LeaderboardMockDatasource implements LeaderboardDatasource {
  @override
  Future<List<LeaderboardEntryModel>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final combined = [
      for (final player in _fictionalPlayers)
        (
          id: player.name,
          name: player.name,
          avatarId: player.avatarId,
          xp: player.xp,
          isMe: false,
        ),
      (
        id: currentUserId,
        name: currentUserName,
        avatarId: currentUserAvatarId,
        xp: currentUserXp,
        isMe: true,
      ),
    ]..sort((a, b) => b.xp.compareTo(a.xp));

    return [
      for (var i = 0; i < combined.length; i++)
        LeaderboardEntryModel(
          rank: i + 1,
          userId: combined[i].id,
          displayName: combined[i].name,
          avatarId: combined[i].avatarId,
          xp: combined[i].xp,
          isCurrentUser: combined[i].isMe,
        ),
    ];
  }

  @override
  Future<List<LeaderboardEntryModel>> getLeaderboard({
    required LeaderboardFilter filter,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    if (filter.scope != LeaderboardScope.global) {
      await Future.delayed(const Duration(milliseconds: 200));
      return const [];
    }

    // Current mock leaderboard has only aggregate XP and no persisted quiz
    // result rows, timestamps, subjects, school, or friend relationships.
    // The filter object is accepted here so the real datasource can apply
    // mode/subject/time queries without changing provider or UI contracts.
    return getGlobalLeaderboard(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatarId: currentUserAvatarId,
      currentUserXp: currentUserXp,
    );
  }
}
