import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardEntryModel extends LeaderboardEntry {
  const LeaderboardEntryModel({
    required super.rank,
    required super.userId,
    required super.displayName,
    required super.avatarId,
    super.avatarUrl,
    super.score,
    super.xp,
    required super.isCurrentUser,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    int parseNum(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return LeaderboardEntryModel(
      rank: parseNum(json['rank'], 0),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      displayName:
          (json['display_name'] ?? json['displayName'] ?? 'Player').toString(),
      avatarId: (json['avatar_id'] ?? json['avatarId'] ?? 'user').toString(),
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      score: parseNum(json['score'] ?? json['xp'], 0),
      isCurrentUser:
          json['is_current_user'] == true || json['isCurrentUser'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'display_name': displayName,
      'avatar_id': avatarId,
      'avatar_url': avatarUrl,
      'score': score,
      'is_current_user': isCurrentUser,
    };
  }
}
