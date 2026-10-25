import 'package:equatable/equatable.dart';

import 'leaderboard_entry.dart';

class LeaderboardPage extends Equatable {
  final List<LeaderboardEntry> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
  final int? currentUserRank;

  const LeaderboardPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
    this.currentUserRank,
  });

  @override
  List<Object?> get props => [
    items,
    page,
    pageSize,
    totalCount,
    hasMore,
    currentUserRank,
  ];
}
