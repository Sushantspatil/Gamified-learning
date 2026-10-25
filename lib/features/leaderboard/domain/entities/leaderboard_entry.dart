import 'package:equatable/equatable.dart';

class LeaderboardEntry extends Equatable {
  final int rank;
  final String userId;
  final String displayName;
  final String avatarId;
  final String? avatarUrl;
  final int score;
  final bool isCurrentUser;

  /// Backwards-compatible getter for legacy callers expecting xp
  int get xp => score;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.avatarId,
    this.avatarUrl,
    int? score,
    int? xp,
    required this.isCurrentUser,
  }) : score = score ?? xp ?? 0;

  LeaderboardEntry copyWith({
    int? rank,
    String? userId,
    String? displayName,
    String? avatarId,
    String? avatarUrl,
    int? score,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      score: score ?? this.score,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  @override
  List<Object?> get props => [
    rank,
    userId,
    displayName,
    avatarId,
    avatarUrl,
    score,
    isCurrentUser,
  ];
}
