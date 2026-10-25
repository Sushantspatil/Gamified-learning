import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/network/network_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/leaderboard/data/datasources/remote/leaderboard_remote_datasource.dart';
import 'package:skillverse_app/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:skillverse_app/features/leaderboard/data/models/leaderboard_response_model.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_filter.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_page.dart';
import 'package:skillverse_app/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:skillverse_app/features/leaderboard/presentation/providers/leaderboard_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';

class _FakeLeaderboardRepository implements LeaderboardRepository {
  int callCount = 0;
  LeaderboardFilter? lastFilter;
  int? lastPage;
  bool shouldThrow = false;

  final Map<int, LeaderboardPage> pages = {};

  @override
  Future<LeaderboardPage> getLeaderboardPage({
    required LeaderboardFilter filter,
    int page = 1,
    int pageSize = 50,
  }) async {
    callCount++;
    lastFilter = filter;
    lastPage = page;

    if (shouldThrow) {
      throw const NetworkException('Connection failed');
    }

    return pages[page] ??
        LeaderboardResponseModel(
          items: [
            LeaderboardEntryModel(
              rank: (page - 1) * pageSize + 1,
              userId: 'user-page-$page',
              displayName: 'User Page $page',
              avatarId: 'robot',
              score: 1000 - (page * 10),
              isCurrentUser: false,
            ),
          ],
          page: page,
          pageSize: pageSize,
          totalCount: 100,
          hasMore: page < 3,
        );
  }

  @override
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    final page = await getLeaderboardPage(
      filter: const LeaderboardFilter(),
      page: 1,
      pageSize: 50,
    );
    return page.items;
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardFilter filter,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    final page = await getLeaderboardPage(
      filter: filter,
      page: 1,
      pageSize: 50,
    );
    return page.items;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Leaderboard Providers', () {
    test('leaderboardDatasourceProvider resolves to LeaderboardRemoteDatasource', () async {
      final storage = await LocalStorageService.create();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(
              config: const ApiConfig(baseUrl: 'https://example.com/api/v1'),
              storage: storage,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final datasource = container.read(leaderboardDatasourceProvider);
      expect(datasource, isA<LeaderboardRemoteDatasource>());
    });

    test('refetches and resets pagination when filter changes', () async {
      final fakeRepo = _FakeLeaderboardRepository();
      final container = ProviderContainer(
        overrides: [
          leaderboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Initial read
      final initial = await container.read(filteredLeaderboardProvider.future);
      expect(initial.page, 1);
      expect(fakeRepo.callCount, 1);
      expect(fakeRepo.lastFilter?.quizType, isNull);

      // Change filter
      container
          .read(leaderboardFilterProvider.notifier)
          .setQuizType(QuestionType.mcq);

      final afterFilter = await container.read(filteredLeaderboardProvider.future);
      expect(afterFilter.page, 1);
      expect(fakeRepo.callCount, 2);
      expect(fakeRepo.lastFilter?.quizType, QuestionType.mcq);
    });

    test('loadMore appends subsequent pages without resetting ranks', () async {
      final fakeRepo = _FakeLeaderboardRepository();
      fakeRepo.pages[1] = const LeaderboardResponseModel(
        items: [
          LeaderboardEntryModel(
            rank: 1,
            userId: 'user-1',
            displayName: 'User 1',
            avatarId: 'robot',
            score: 100,
            isCurrentUser: false,
          ),
        ],
        page: 1,
        pageSize: 1,
        totalCount: 2,
        hasMore: true,
      );
      fakeRepo.pages[2] = const LeaderboardResponseModel(
        items: [
          LeaderboardEntryModel(
            rank: 2,
            userId: 'user-2',
            displayName: 'User 2',
            avatarId: 'owl',
            score: 80,
            isCurrentUser: false,
          ),
        ],
        page: 2,
        pageSize: 1,
        totalCount: 2,
        hasMore: false,
      );

      final container = ProviderContainer(
        overrides: [
          leaderboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final page1 = await container.read(filteredLeaderboardProvider.future);
      expect(page1.entries.length, 1);
      expect(page1.entries.first.rank, 1);
      expect(page1.hasMore, isTrue);

      await container.read(filteredLeaderboardProvider.notifier).loadMore();

      final page2State = container.read(filteredLeaderboardProvider).value!;
      expect(page2State.entries.length, 2);
      expect(page2State.entries[0].rank, 1);
      expect(page2State.entries[1].rank, 2);
      expect(page2State.page, 2);
      expect(page2State.hasMore, isFalse);
    });

    test('preserves error state and allows successful retry', () async {
      final fakeRepo = _FakeLeaderboardRepository();
      fakeRepo.shouldThrow = true;

      final container = ProviderContainer(
        overrides: [
          leaderboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Initial read fails
      await expectLater(
        container.read(filteredLeaderboardProvider.future),
        throwsA(isA<NetworkException>()),
      );

      // Now fix repo and retry
      fakeRepo.shouldThrow = false;
      await container.read(filteredLeaderboardProvider.notifier).refresh();

      final state = container.read(filteredLeaderboardProvider).value!;
      expect(state.entries.length, 1);
      expect(state.page, 1);
    });
  });
}
