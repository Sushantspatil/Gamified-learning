import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../data/datasources/leaderboard_datasource.dart';
import '../../data/datasources/remote/leaderboard_remote_datasource.dart';
import '../../data/models/leaderboard_entry_model.dart';
import '../../data/models/leaderboard_response_model.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_filter.dart';
import '../../domain/repositories/leaderboard_repository.dart';

/// Real API-backed datasource provider for production.
final leaderboardDatasourceProvider = Provider<LeaderboardDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LeaderboardRemoteDatasource(apiClient);
});

class EmptyLeaderboardDatasource implements LeaderboardDatasource {
  const EmptyLeaderboardDatasource();

  @override
  Future<LeaderboardResponseModel> getLeaderboardPage({
    required LeaderboardFilter filter,
    int page = 1,
    int pageSize = 50,
  }) async {
    return LeaderboardResponseModel(
      items: const [],
      page: page,
      pageSize: pageSize,
      totalCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<List<LeaderboardEntryModel>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    return const [];
  }

  @override
  Future<List<LeaderboardEntryModel>> getLeaderboard({
    required LeaderboardFilter filter,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    return const [];
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepositoryImpl(ref.watch(leaderboardDatasourceProvider));
});

class LeaderboardFilterController extends Notifier<LeaderboardFilter> {
  @override
  LeaderboardFilter build() => const LeaderboardFilter();

  void setQuizType(QuestionType? quizType) {
    state = state.copyWith(quizType: quizType, clearQuizType: quizType == null);
  }

  void setSubject(String? subjectId) {
    state = state.copyWith(
      subjectId: subjectId,
      clearSubjectId: subjectId == null,
    );
  }

  void setTimeRange(LeaderboardTimeRange timeRange) {
    state = state.copyWith(timeRange: timeRange);
  }

  void setScope(LeaderboardScope scope) {
    state = state.copyWith(scope: scope);
  }
}

final leaderboardFilterProvider =
    NotifierProvider<LeaderboardFilterController, LeaderboardFilter>(
  LeaderboardFilterController.new,
);

class LeaderboardState extends Equatable {
  final List<LeaderboardEntry> entries;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final int? currentUserRank;

  const LeaderboardState({
    required this.entries,
    this.page = 1,
    this.pageSize = 50,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.currentUserRank,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    int? page,
    int? pageSize,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    int? currentUserRank,
    bool clearCurrentUserRank = false,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentUserRank: clearCurrentUserRank
          ? null
          : (currentUserRank ?? this.currentUserRank),
    );
  }

  @override
  List<Object?> get props => [
    entries,
    page,
    pageSize,
    totalCount,
    hasMore,
    isLoadingMore,
    currentUserRank,
  ];
}

class FilteredLeaderboardNotifier extends AsyncNotifier<LeaderboardState> {
  @override
  Future<LeaderboardState> build() async {
    final filter = ref.watch(leaderboardFilterProvider);
    final repository = ref.watch(leaderboardRepositoryProvider);

    final page = await repository.getLeaderboardPage(
      filter: filter,
      page: 1,
      pageSize: 50,
    );

    return LeaderboardState(
      entries: page.items,
      page: page.page,
      pageSize: page.pageSize,
      totalCount: page.totalCount,
      hasMore: page.hasMore,
      currentUserRank: page.currentUserRank,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final filter = ref.read(leaderboardFilterProvider);
      final repository = ref.read(leaderboardRepositoryProvider);
      final nextPageNum = current.page + 1;

      final nextPage = await repository.getLeaderboardPage(
        filter: filter,
        page: nextPageNum,
        pageSize: current.pageSize,
      );

      final existingIds = current.entries.map((e) => e.userId).toSet();
      final newItems =
          nextPage.items.where((e) => !existingIds.contains(e.userId)).toList();

      state = AsyncData(
        current.copyWith(
          entries: [...current.entries, ...newItems],
          page: nextPage.page,
          pageSize: nextPage.pageSize,
          totalCount: nextPage.totalCount,
          hasMore: nextPage.hasMore,
          isLoadingMore: false,
          currentUserRank: nextPage.currentUserRank ?? current.currentUserRank,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final filteredLeaderboardProvider =
    AsyncNotifierProvider<FilteredLeaderboardNotifier, LeaderboardState>(
  FilteredLeaderboardNotifier.new,
);

final globalLeaderboardProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) async {
  final repository = ref.watch(leaderboardRepositoryProvider);
  final page = await repository.getLeaderboardPage(
    filter: const LeaderboardFilter(),
    page: 1,
    pageSize: 50,
  );
  return page.items;
});
