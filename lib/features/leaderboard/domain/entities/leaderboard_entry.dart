import 'package:equatable/equatable.dart';

class LeaderboardEntry extends Equatable {
  final int rank;
  final String userId;
  final String displayName;
  final String avatarId;
  final int xp;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.avatarId,
    required this.xp,
    required this.isCurrentUser,
  });

  @override
  List<Object?> get props => [rank, userId, displayName, avatarId, xp, isCurrentUser];
}
