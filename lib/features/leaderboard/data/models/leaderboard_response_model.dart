import '../../domain/entities/leaderboard_page.dart';
import 'leaderboard_entry_model.dart';

class LeaderboardResponseModel extends LeaderboardPage {
  const LeaderboardResponseModel({
    required super.items,
    required super.page,
    required super.pageSize,
    required super.totalCount,
    required super.hasMore,
    super.currentUserRank,
  });

  factory LeaderboardResponseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <LeaderboardEntryModel>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(LeaderboardEntryModel.fromJson(item));
        } else if (item is Map) {
          items.add(
            LeaderboardEntryModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    int parseNum(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    int? parseNullableNum(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final page = parseNum(json['page'], 1);
    final pageSize = parseNum(json['page_size'] ?? json['pageSize'], 50);
    final totalCount = parseNum(
      json['total_count'] ?? json['totalCount'],
      items.length,
    );
    final hasMore = json['has_more'] is bool
        ? json['has_more'] as bool
        : (json['hasMore'] is bool ? json['hasMore'] as bool : false);
    final currentUserRank = parseNullableNum(
      json['current_user_rank'] ?? json['currentUserRank'],
    );

    return LeaderboardResponseModel(
      items: items,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      hasMore: hasMore,
      currentUserRank: currentUserRank,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items
          .map((e) => (e is LeaderboardEntryModel)
              ? e.toJson()
              : {
                  'rank': e.rank,
                  'user_id': e.userId,
                  'display_name': e.displayName,
                  'avatar_id': e.avatarId,
                  'avatar_url': e.avatarUrl,
                  'score': e.score,
                  'is_current_user': e.isCurrentUser,
                })
          .toList(),
      'page': page,
      'page_size': pageSize,
      'total_count': totalCount,
      'has_more': hasMore,
      'current_user_rank': currentUserRank,
    };
  }
}
