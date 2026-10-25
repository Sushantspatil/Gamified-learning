import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../questions/domain/entities/question.dart';
import '../../../domain/entities/leaderboard_filter.dart';
import '../../models/leaderboard_entry_model.dart';
import '../../models/leaderboard_response_model.dart';
import '../leaderboard_datasource.dart';

class LeaderboardRemoteDatasource implements LeaderboardDatasource {
  final ApiClient _apiClient;

  LeaderboardRemoteDatasource(this._apiClient);

  static String mapTimeRange(LeaderboardTimeRange range) {
    return switch (range) {
      LeaderboardTimeRange.daily => 'daily',
      LeaderboardTimeRange.weekly => 'weekly',
      LeaderboardTimeRange.monthly => 'monthly',
      LeaderboardTimeRange.allTime => 'all_time',
    };
  }

  static String mapScope(LeaderboardScope scope) {
    return switch (scope) {
      LeaderboardScope.global => 'global',
      LeaderboardScope.school => 'school',
      LeaderboardScope.friends => 'friends',
    };
  }

  @override
  Future<LeaderboardResponseModel> getLeaderboardPage({
    required LeaderboardFilter filter,
    int page = 1,
    int pageSize = 50,
  }) async {
    // Backend only supports global scope. Friends and School scopes are intentionally
    // unsupported backend-side without relationship tables. Do not send invalid requests.
    if (filter.scope != LeaderboardScope.global) {
      return LeaderboardResponseModel(
        items: const [],
        page: page,
        pageSize: pageSize,
        totalCount: 0,
        hasMore: false,
      );
    }

    final queryParams = <String, String>{
      'scope': mapScope(filter.scope),
      'time_range': mapTimeRange(filter.timeRange),
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (filter.quizType != null) {
      queryParams['game_mode'] = filter.quizType!.backendGameMode;
    }

    if (filter.subjectId != null && filter.subjectId!.trim().isNotEmpty) {
      queryParams['subject_id'] = filter.subjectId!.trim();
    }

    final response = await _apiClient.get(
      ApiEndpoints.leaderboard,
      queryParams: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return LeaderboardResponseModel.fromJson(response);
    } else if (response is Map) {
      return LeaderboardResponseModel.fromJson(
        Map<String, dynamic>.from(response),
      );
    } else if (response is List) {
      final items = response
          .whereType<Map>()
          .map((m) =>
              LeaderboardEntryModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return LeaderboardResponseModel(
        items: items,
        page: page,
        pageSize: pageSize,
        totalCount: items.length,
        hasMore: false,
      );
    }

    return LeaderboardResponseModel(
      items: const [],
      page: page,
      pageSize: pageSize,
      totalCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<List<LeaderboardEntryModel>> getLeaderboard({
    required LeaderboardFilter filter,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    final response = await getLeaderboardPage(
      filter: filter,
      page: 1,
      pageSize: 50,
    );
    return response.items.cast<LeaderboardEntryModel>();
  }

  @override
  Future<List<LeaderboardEntryModel>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    return getLeaderboard(
      filter: const LeaderboardFilter(),
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserAvatarId: currentUserAvatarId,
      currentUserXp: currentUserXp,
    );
  }
}
