import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:skillverse_app/features/leaderboard/data/models/leaderboard_response_model.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_filter.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_page.dart';
import 'package:skillverse_app/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:skillverse_app/features/leaderboard/presentation/providers/leaderboard_providers.dart';
import 'package:skillverse_app/features/leaderboard/presentation/screens/leaderboard_screen.dart';
import 'package:skillverse_app/features/learning_paths/domain/entities/learning_path.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';

class _MockLeaderboardRepo implements LeaderboardRepository {
  Completer<LeaderboardPage>? pendingCompleter;
  bool shouldFail = false;
  int fetchCount = 0;
  LeaderboardFilter? lastFilter;
  int? lastPage;

  final Map<int, LeaderboardPage> customPages = {};

  @override
  Future<LeaderboardPage> getLeaderboardPage({
    required LeaderboardFilter filter,
    int page = 1,
    int pageSize = 50,
  }) async {
    fetchCount++;
    lastFilter = filter;
    lastPage = page;

    if (pendingCompleter != null && !pendingCompleter!.isCompleted) {
      return pendingCompleter!.future;
    }

    if (shouldFail) {
      throw const NetworkException('Failed to connect to backend server');
    }

    return customPages[page] ??
        LeaderboardResponseModel(
          items: [
            const LeaderboardEntryModel(
              rank: 1,
              userId: 'user-1',
              displayName: 'Alex Top',
              avatarId: 'robot',
              score: 1250,
              isCurrentUser: false,
            ),
            const LeaderboardEntryModel(
              rank: 2,
              userId: 'user-me',
              displayName: 'Current Player',
              avatarId: 'owl',
              score: 800,
              isCurrentUser: true,
            ),
            const LeaderboardEntryModel(
              rank: 42,
              userId: 'user-zero',
              displayName: 'Zero Score Player',
              avatarId: 'user',
              score: 0,
              isCurrentUser: false,
            ),
          ],
          page: page,
          pageSize: pageSize,
          totalCount: 3,
          hasMore: page == 1 && customPages.containsKey(2),
          currentUserRank: 2,
        );
  }

  @override
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatarId,
    required int currentUserXp,
  }) async {
    final page = await getLeaderboardPage(filter: const LeaderboardFilter());
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
    final page = await getLeaderboardPage(filter: filter);
    return page.items;
  }
}

Future<Widget> _buildTestApp({
  required _MockLeaderboardRepo repo,
  LocalStorageService? storage,
}) async {
  final storageService = storage ?? await LocalStorageService.create();
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storageService),
      leaderboardRepositoryProvider.overrideWithValue(repo),
      learningPathsProvider.overrideWith((ref) async => const [
            LearningPath(
              id: 'accounting',
              title: 'Accounting',
              description: 'Basics of Accounting',
              difficulty: LearningPathDifficulty.beginner,
              topicCount: 1,
            ),
          ]),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: const LeaderboardScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LeaderboardScreen Widget Tests', () {
    testWidgets('renders loading state initially while request is in flight',
        (tester) async {
      final repo = _MockLeaderboardRepo();
      repo.pendingCompleter = Completer<LeaderboardPage>();

      final app = await _buildTestApp(repo: repo);
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error message and working Retry action on failure',
        (tester) async {
      final repo = _MockLeaderboardRepo();
      repo.shouldFail = true;

      final app = await _buildTestApp(repo: repo);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Could not load the leaderboard.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now fix failure and tap Retry
      repo.shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Alex Top'), findsOneWidget);
      expect(find.text('1,250 points'), findsOneWidget);
    });

    testWidgets('renders real entries, scores in points, and highlights current user',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _MockLeaderboardRepo();

      final app = await _buildTestApp(repo: repo);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Top Score Hero Card
      expect(find.text('Weekly arena'), findsOneWidget);
      expect(find.text('Top score: 1,250 points'), findsOneWidget);
      expect(find.text('Your rank: #2'), findsOneWidget);

      // Entries
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Alex Top'), findsOneWidget);
      expect(find.text('1,250 points'), findsOneWidget);

      // Current user highlight
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Current Player (You)'), findsOneWidget);
      expect(find.text('800 points'), findsOneWidget);

      // Zero-score user visibility
      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Zero Score Player'), findsOneWidget);
      expect(find.text('0 points'), findsOneWidget);
    });

    testWidgets('renders empty state when server returns zero entries',
        (tester) async {
      final repo = _MockLeaderboardRepo();
      repo.customPages[1] = const LeaderboardResponseModel(
        items: [],
        page: 1,
        pageSize: 50,
        totalCount: 0,
        hasMore: false,
      );

      final app = await _buildTestApp(repo: repo);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('No global ranking data available yet.'), findsOneWidget);
      // Filter card is still visible so user can change filters
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('Friends and School tabs remain honestly unavailable',
        (tester) async {
      final repo = _MockLeaderboardRepo();

      final app = await _buildTestApp(repo: repo);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Tap Friends Tab
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(find.text('Friends leaderboard is coming soon.'), findsOneWidget);

      // Tap School Tab
      await tester.tap(find.text('School'));
      await tester.pumpAndSettle();
      expect(find.text('School leaderboard is coming soon.'), findsOneWidget);
    });

    testWidgets('changing filter chips updates the hero card and triggers new request',
        (tester) async {
      final repo = _MockLeaderboardRepo();

      final app = await _buildTestApp(repo: repo);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Weekly arena'), findsOneWidget);

      // Tap Daily chip
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();

      expect(find.text('Daily arena'), findsOneWidget);
      expect(repo.lastFilter?.timeRange, LeaderboardTimeRange.daily);

      // Tap Monthly chip
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly arena'), findsOneWidget);
      expect(repo.lastFilter?.timeRange, LeaderboardTimeRange.monthly);

      // Tap All Time chip
      await tester.tap(find.text('All Time'));
      await tester.pumpAndSettle();

      expect(find.text('All Time arena'), findsOneWidget);
      expect(repo.lastFilter?.timeRange, LeaderboardTimeRange.allTime);
    });

    testWidgets('pagination loads additional users via Load more button without resetting ranks',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _MockLeaderboardRepo();
      repo.customPages[1] = const LeaderboardResponseModel(
        items: [
          LeaderboardEntryModel(
            rank: 1,
            userId: 'u-1',
            displayName: 'Rank One',
            avatarId: 'robot',
            score: 500,
            isCurrentUser: false,
          ),
        ],
        page: 1,
        pageSize: 1,
        totalCount: 2,
        hasMore: true,
      );
      repo.customPages[2] = const LeaderboardResponseModel(
        items: [
          LeaderboardEntryModel(
            rank: 2,
            userId: 'u-2',
            displayName: 'Rank Two',
            avatarId: 'owl',
            score: 400,
            isCurrentUser: false,
          ),
        ],
        page: 2,
        pageSize: 1,
        totalCount: 2,
        hasMore: false,
      );

      final app = await _buildTestApp(repo: repo);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Rank One'), findsOneWidget);
      expect(find.text('Rank Two'), findsNothing);
      expect(find.text('Load more'), findsOneWidget);

      // Tap Load more
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Rank One'), findsOneWidget);
      expect(find.text('Rank Two'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });
  });
}
