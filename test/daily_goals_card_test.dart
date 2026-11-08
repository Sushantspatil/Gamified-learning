import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/data/models/user_model.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/chapters/data/datasources/mock/chapter_mock_datasource.dart';
import 'package:skillverse_app/features/chapters/presentation/providers/chapter_providers.dart';
import 'package:skillverse_app/features/daily_missions/data/datasources/daily_mission_datasource.dart';
import 'package:skillverse_app/features/daily_missions/data/models/daily_mission_model.dart';
import 'package:skillverse_app/features/daily_missions/presentation/providers/daily_mission_providers.dart';
import 'package:skillverse_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:skillverse_app/features/learning_paths/data/datasources/mock/learning_path_mock_datasource.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/profile/data/datasources/mock/profile_mock_datasource.dart';
import 'package:skillverse_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:skillverse_app/features/streaks/data/datasources/mock/streak_mock_datasource.dart';
import 'package:skillverse_app/features/streaks/data/datasources/remote/streak_rewards_remote_datasource.dart';
import 'package:skillverse_app/features/streaks/domain/entities/streak_rewards.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_providers.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_rewards_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

/// No streak rewards (keeps this test off the network).
class _NoStreakRewards implements StreakRewardsRemoteDatasource {
  @override
  Future<StreakRewards?> fetch() async => null;
  @override
  Future<void> claim(int days) async {}
}

/// A signed-in player (goals are only loaded for someone who is signed in).
class _SignedInAuth extends AuthController {
  @override
  Future<AppUser?> build() async => const UserModel(
    id: 'mock-user-0',
    email: 'test@example.com',
    displayName: 'Test User',
  );
}

/// A stand-in for the backend's daily goals: keeps the goals in memory and
/// "pays" a claim by flipping the goal to claimed.
class _FakeGoals implements DailyMissionDatasource {
  _FakeGoals(this.goals);

  List<DailyMissionModel> goals;
  final claims = <String>[];
  Object? claimError;

  @override
  Future<List<DailyMissionModel>> getTodayMissions(String userId) async =>
      goals;

  @override
  Future<DailyMissionModel> recordQuizCompleted(String userId) =>
      throw UnsupportedError('not used');

  @override
  Future<void> claimMission(String userId, String missionId) async {
    claims.add(missionId);
    final error = claimError;
    if (error != null) throw error;
    goals = [
      for (final g in goals)
        if (g.id == missionId)
          DailyMissionModel(
            id: g.id,
            title: g.title,
            targetCount: g.targetCount,
            progressCount: g.progressCount,
            coinReward: g.coinReward,
            currency: g.currency,
            claimed: true,
          )
        else
          g,
    ];
  }
}

DailyMissionModel _goal(
  String id,
  String title, {
  required int target,
  required int progress,
  int reward = 20,
  String currency = 'coins',
  bool claimed = false,
}) => DailyMissionModel(
  id: id,
  title: title,
  targetCount: target,
  progressCount: progress,
  coinReward: reward,
  currency: currency,
  claimed: claimed,
);

Future<void> _show(WidgetTester tester, _FakeGoals goals) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  tester.view.physicalSize = const Size(720, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        authControllerProvider.overrideWith(_SignedInAuth.new),
        learningPathDatasourceProvider.overrideWithValue(
          LearningPathMockDatasource(),
        ),
        chapterDatasourceProvider.overrideWithValue(ChapterMockDatasource()),
        profileDatasourceProvider.overrideWithValue(ProfileMockDatasource()),
        streakDatasourceProvider.overrideWithValue(StreakMockDatasource()),
        walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
        dailyMissionDatasourceProvider.overrideWithValue(goals),
        streakRewardsDatasourceProvider.overrideWithValue(_NoStreakRewards()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollToGoals(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.text('Today\'s goal'),
    find.byType(ListView).first,
    const Offset(0, -300),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('no goals from the server: the card is left out', (tester) async {
    await _show(tester, _FakeGoals([]));
    expect(find.text('Today\'s goal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows progress, a Collect button, and Collected', (
    tester,
  ) async {
    final goals = _FakeGoals([
      _goal('play_1', 'Finish 1 game', target: 1, progress: 1),
      _goal('play_3', 'Finish 3 games', target: 3, progress: 1, reward: 40),
      _goal(
        'score_100',
        'Score 100 points',
        target: 100,
        progress: 100,
        reward: 2,
        currency: 'gems',
        claimed: true,
      ),
    ]);
    await _show(tester, goals);
    await _scrollToGoals(tester);

    expect(find.text('Finish 3 games'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget); // in progress
    expect(find.text('+40 coins'), findsOneWidget); // reward preview
    expect(find.byKey(const Key('collect_goal_play_1')), findsOneWidget);
    expect(find.text('Collect +20 coins'), findsOneWidget);
    expect(find.byKey(const Key('collect_goal_score_100')), findsNothing);
    expect(find.text('Collected'), findsOneWidget); // the claimed gems goal
    expect(find.text('1 reward ready to collect'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Collect claims once and shows Collected', (
    tester,
  ) async {
    final goals = _FakeGoals([
      _goal('play_1', 'Finish 1 game', target: 1, progress: 1),
    ]);
    await _show(tester, goals);
    await _scrollToGoals(tester);

    await tester.tap(find.byKey(const Key('collect_goal_play_1')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(goals.claims, ['play_1']);
    expect(find.byKey(const Key('collect_goal_play_1')), findsNothing);
    expect(find.text('Collected'), findsOneWidget);
    expect(find.text('+20 coins collected!'), findsOneWidget);
    expect(
      find.text('All rewards collected. New goals tomorrow!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused claim shows the reason and re-reads the goals', (
    tester,
  ) async {
    final goals =
        _FakeGoals([_goal('play_1', 'Finish 1 game', target: 1, progress: 1)])
          ..claimError = const ValidationException(
            'daily goal reward already claimed',
          );
    await _show(tester, goals);
    await _scrollToGoals(tester);

    await tester.tap(find.byKey(const Key('collect_goal_play_1')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('daily goal reward already claimed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
