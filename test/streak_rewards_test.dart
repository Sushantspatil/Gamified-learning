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

class _SignedInAuth extends AuthController {
  @override
  Future<AppUser?> build() async => const UserModel(
    id: 'mock-user-0',
    email: 'test@example.com',
    displayName: 'Test User',
  );
}

class _NoGoals implements DailyMissionDatasource {
  @override
  Future<List<DailyMissionModel>> getTodayMissions(String userId) async =>
      const [];
  @override
  Future<DailyMissionModel> recordQuizCompleted(String userId) =>
      throw UnsupportedError('not used');
  @override
  Future<void> claimMission(String userId, String missionId) async {}
}

/// Stands in for the backend: holds the rewards, and "pays" a claim by
/// marking that milestone collected.
class _FakeStreakRewards implements StreakRewardsRemoteDatasource {
  _FakeStreakRewards(this.rewards);

  StreakRewards? rewards;
  final claims = <int>[];
  Object? claimError;

  @override
  Future<StreakRewards?> fetch() async => rewards;

  @override
  Future<void> claim(int days) async {
    claims.add(days);
    final error = claimError;
    if (error != null) throw error;
    final current = rewards!;
    rewards = StreakRewards(
      currentStreak: current.currentStreak,
      milestones: [
        for (final m in current.milestones)
          if (m.days == days)
            StreakMilestone(
              days: m.days,
              currency: m.currency,
              reward: m.reward,
              reached: m.reached,
              claimed: true,
            )
          else
            m,
      ],
    );
  }
}

StreakMilestone _m(
  int days,
  int reward, {
  String currency = 'coins',
  bool reached = false,
  bool claimed = false,
}) => StreakMilestone(
  days: days,
  currency: currency,
  reward: reward,
  reached: reached,
  claimed: claimed,
);

Future<void> _show(WidgetTester tester, _FakeStreakRewards fake) async {
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
        dailyMissionDatasourceProvider.overrideWithValue(_NoGoals()),
        streakRewardsDatasourceProvider.overrideWithValue(fake),
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

Future<void> _scrollToStreak(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.text('Your streak'),
    find.byType(ListView).first,
    const Offset(0, -300),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('parse', () {
    test('reads the rewards from the server response', () {
      final r = StreakRewardsRemoteDatasource.parse({
        'current': 7,
        'highest': 9,
        'milestones': [
          {
            'days': 3,
            'currency': 'coins',
            'reward': 20,
            'reached': true,
            'claimed': true,
          },
          {
            'days': 14,
            'currency': 'gems',
            'reward': 5,
            'reached': false,
            'claimed': false,
          },
        ],
      });
      expect(r, isNotNull);
      expect(r!.currentStreak, 7);
      expect(r.milestones.length, 2);
      expect(r.milestones[0].claimed, isTrue);
      expect(r.milestones[1].currency, 'gems');
      expect(r.milestones[1].rewardLabel, '+5 gems');
      expect(r.claimable, isNull);
      expect(r.next?.days, 14);
    });

    test('a bad row is skipped and a bad response is no rewards', () {
      final r = StreakRewardsRemoteDatasource.parse({
        'current': 3,
        'milestones': [
          {'days': 'three', 'reward': 20},
          {'days': 3, 'reward': 20, 'reached': true},
          'nonsense',
        ],
      });
      expect(r!.milestones.length, 1);
      expect(r.claimable?.days, 3);
      expect(StreakRewardsRemoteDatasource.parse('nope'), isNull);
      expect(StreakRewardsRemoteDatasource.parse({'current': 1}), isNull);
    });
  });

  testWidgets('a server without streak rewards shows nothing extra', (
    tester,
  ) async {
    await _show(tester, _FakeStreakRewards(null));
    await _scrollToStreak(tester);
    expect(find.byKey(const Key('streak_rewards_strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows how far the next reward is', (tester) async {
    await _show(
      tester,
      _FakeStreakRewards(
        StreakRewards(
          currentStreak: 5,
          milestones: [_m(3, 20, reached: true, claimed: true), _m(7, 50)],
        ),
      ),
    );
    await _scrollToStreak(tester);
    expect(find.byKey(const Key('streak_rewards_strip')), findsOneWidget);
    expect(find.text('2 more days for +50 coins'), findsOneWidget);
    expect(find.byKey(const Key('collect_streak_7')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reached reward can be collected once', (tester) async {
    final fake = _FakeStreakRewards(
      StreakRewards(
        currentStreak: 7,
        milestones: [
          _m(3, 20, reached: true, claimed: true),
          _m(7, 50, reached: true),
          _m(14, 5, currency: 'gems'),
        ],
      ),
    );
    await _show(tester, fake);
    await _scrollToStreak(tester);

    expect(find.text('7-day streak reward'), findsOneWidget);
    expect(find.text('Collect +50 coins'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collect_streak_7')));
    await _settle(tester);

    expect(fake.claims, [7]);
    expect(find.byKey(const Key('collect_streak_7')), findsNothing);
    expect(find.text('+50 coins collected!'), findsOneWidget);
    expect(find.text('7 more days for +5 gems'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused claim shows the reason', (tester) async {
    final fake =
        _FakeStreakRewards(
            StreakRewards(
              currentStreak: 3,
              milestones: [_m(3, 20, reached: true)],
            ),
          )
          ..claimError = const ValidationException(
            'streak milestone not reached yet',
          );
    await _show(tester, fake);
    await _scrollToStreak(tester);

    await tester.tap(find.byKey(const Key('collect_streak_3')));
    await _settle(tester);

    expect(find.text('streak milestone not reached yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('everything collected: a keep-going message', (tester) async {
    await _show(
      tester,
      _FakeStreakRewards(
        StreakRewards(
          currentStreak: 31,
          milestones: [
            _m(3, 20, reached: true, claimed: true),
            _m(30, 150, reached: true, claimed: true),
          ],
        ),
      ),
    );
    await _scrollToStreak(tester);
    expect(
      find.text('All streak rewards collected. Keep it going!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
