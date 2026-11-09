import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/models/user_model.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/daily_missions/data/datasources/daily_mission_datasource.dart';
import 'package:skillverse_app/features/daily_missions/data/models/daily_mission_model.dart';
import 'package:skillverse_app/features/daily_missions/domain/entities/daily_mission.dart';
import 'package:skillverse_app/features/daily_missions/presentation/providers/daily_mission_providers.dart';
import 'package:skillverse_app/features/habit/domain/next_step.dart';
import 'package:skillverse_app/features/habit/presentation/next_step_widgets.dart';
import 'package:skillverse_app/features/streaks/data/datasources/remote/streak_rewards_remote_datasource.dart';
import 'package:skillverse_app/features/streaks/domain/entities/streak_rewards.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_rewards_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

DailyMission _goal(
  String id,
  String title, {
  required int target,
  required int progress,
  int reward = 20,
  String currency = 'coins',
  bool claimed = false,
}) => DailyMission(
  id: id,
  title: title,
  targetCount: target,
  progressCount: progress,
  coinReward: reward,
  currency: currency,
  claimed: claimed,
);

StreakMilestone _m(
  int days,
  int reward, {
  bool reached = false,
  bool claimed = false,
}) => StreakMilestone(
  days: days,
  currency: 'coins',
  reward: reward,
  reached: reached,
  claimed: claimed,
);

void main() {
  group('decideNextStep', () {
    test('nothing from the server: nothing to show', () {
      expect(decideNextStep(missions: const []), isNull);
      expect(
        decideNextStep(
          missions: const [],
          streakRewards: StreakRewards(
            currentStreak: 1,
            milestones: [_m(3, 20)],
          ),
        ),
        isNull,
        reason: 'streak progress alone is not a next step',
      );
    });

    test('a finished goal is collected before anything else', () {
      final step = decideNextStep(
        missions: [
          _goal('a', 'Finish 3 games', target: 3, progress: 2),
          _goal('b', 'Finish 1 game', target: 1, progress: 1),
        ],
        streakRewards: StreakRewards(
          currentStreak: 3,
          milestones: [_m(3, 20, reached: true)],
        ),
      );
      expect(step, isA<CollectGoal>());
      final collect = step! as CollectGoal;
      expect(collect.mission.id, 'b');
      expect(
        collect.readyCount,
        2,
        reason: 'the goal and the streak reward are both waiting',
      );
    });

    test('a streak reward is next when no goal is waiting', () {
      final step = decideNextStep(
        missions: [_goal('a', 'Finish 3 games', target: 3, progress: 1)],
        streakRewards: StreakRewards(
          currentStreak: 7,
          milestones: [
            _m(3, 20, reached: true, claimed: true),
            _m(7, 50, reached: true),
          ],
        ),
      );
      expect(step, isA<CollectStreakReward>());
      final collect = step! as CollectStreakReward;
      expect(collect.milestone.days, 7);
      expect(collect.readyCount, 1);
    });

    test('a streak reward can be collected even with no goals', () {
      final step = decideNextStep(
        missions: const [],
        streakRewards: StreakRewards(
          currentStreak: 3,
          milestones: [_m(3, 20, reached: true)],
        ),
      );
      expect(step, isA<CollectStreakReward>());
    });

    test('the goal closest to done is the one to continue', () {
      final step = decideNextStep(
        missions: [
          _goal('far', 'Score 100 points', target: 100, progress: 10),
          _goal('near', 'Finish 3 games', target: 3, progress: 2),
          _goal('done', 'Finish 1 game', target: 1, progress: 1, claimed: true),
        ],
      );
      expect(step, isA<ContinueGoal>());
      final next = step! as ContinueGoal;
      expect(next.mission.id, 'near');
      expect(next.remaining, 1);
      expect(next.goalsDone, 1);
      expect(next.goalsTotal, 3);
    });

    test('equally close goals: the smaller one first', () {
      final step = decideNextStep(
        missions: [
          _goal('big', 'Finish 3 games', target: 3, progress: 1),
          _goal('small', 'Finish 2 games', target: 2, progress: 0),
        ],
      );
      expect((step! as ContinueGoal).mission.id, 'small');
    });

    test('everything done and collected: all done, with the streak ahead', () {
      final step = decideNextStep(
        missions: [
          _goal('a', 'Finish 1 game', target: 1, progress: 1, claimed: true),
        ],
        streakRewards: StreakRewards(
          currentStreak: 5,
          milestones: [_m(3, 20, reached: true, claimed: true), _m(7, 50)],
        ),
      );
      expect(step, isA<AllGoalsDone>());
      final done = step! as AllGoalsDone;
      expect(done.nextStreakReward?.days, 7);
      expect(done.daysToNextStreakReward, 2);
    });

    test('all done with no streak reward left', () {
      final step = decideNextStep(
        missions: [
          _goal('a', 'Finish 1 game', target: 1, progress: 1, claimed: true),
        ],
      );
      final done = step! as AllGoalsDone;
      expect(done.nextStreakReward, isNull);
      expect(done.daysToNextStreakReward, 0);
    });
  });

  group('the widgets', () {
    Future<_Harness> show(
      WidgetTester tester, {
      required List<DailyMissionModel> goals,
      StreakRewards? rewards,
      bool panel = false,
      bool withScope = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final harness = _Harness(_Goals(goals), _Rewards(rewards));
      final child = panel ? const NextStepPanel() : const NextStepCard();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: SingleChildScrollView(child: child)),
          ),
          GoRoute(
            path: '/practice',
            builder: (_, _) => const Scaffold(body: Text('PRACTICE SCREEN')),
          ),
        ],
      );
      final app = MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      );
      await tester.pumpWidget(
        withScope
            ? ProviderScope(
                overrides: [
                  localStorageServiceProvider.overrideWithValue(storage),
                  authControllerProvider.overrideWith(_SignedIn.new),
                  walletDatasourceProvider.overrideWithValue(
                    WalletMockDatasource(),
                  ),
                  dailyMissionDatasourceProvider.overrideWithValue(
                    harness.goals,
                  ),
                  streakRewardsDatasourceProvider.overrideWithValue(
                    harness.rewards,
                  ),
                ],
                child: app,
              )
            : MaterialApp(
                theme: AppTheme.lightTheme,
                home: Scaffold(body: child),
              ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      return harness;
    }

    DailyMissionModel model(
      String id,
      String title, {
      required int target,
      required int progress,
      int reward = 20,
      bool claimed = false,
    }) => DailyMissionModel(
      id: id,
      title: title,
      targetCount: target,
      progressCount: progress,
      coinReward: reward,
      claimed: claimed,
    );

    testWidgets(
      'home card: a goal in progress shows its progress and Play now',
      (tester) async {
        await show(
          tester,
          goals: [
            model(
              'play_3',
              'Finish 3 games',
              target: 3,
              progress: 1,
              reward: 40,
            ),
          ],
        );
        expect(find.byKey(const Key('next_step_card')), findsOneWidget);
        expect(find.text('Finish 3 games'), findsOneWidget);
        expect(find.textContaining('1 of 3'), findsWidgets);
        expect(find.textContaining('+40 coins'), findsWidgets);
        expect(find.text('Play now'), findsOneWidget);

        await tester.tap(find.byKey(const Key('next_step_action')));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(find.text('PRACTICE SCREEN'), findsOneWidget);
      },
    );

    testWidgets(
      'home card: a finished goal is collected, then the next step shows',
      (tester) async {
        final h = await show(
          tester,
          goals: [
            model('play_1', 'Finish 1 game', target: 1, progress: 1),
            model(
              'play_3',
              'Finish 3 games',
              target: 3,
              progress: 1,
              reward: 40,
            ),
          ],
        );
        expect(find.text('Goal complete!'), findsOneWidget);
        expect(find.text('Collect +20 coins'), findsOneWidget);

        await tester.tap(find.byKey(const Key('next_step_action')));
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }

        expect(h.goals.claims, ['play_1']);
        expect(find.text('+20 coins collected!'), findsOneWidget);
        // Collecting moved on to the next goal.
        expect(find.text('Finish 3 games'), findsOneWidget);
        expect(find.text('Play now'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('home card: a streak reward can be collected too', (
      tester,
    ) async {
      final h = await show(
        tester,
        goals: [
          model(
            'play_1',
            'Finish 1 game',
            target: 1,
            progress: 1,
            claimed: true,
          ),
        ],
        rewards: StreakRewards(
          currentStreak: 3,
          milestones: [_m(3, 20, reached: true), _m(7, 50)],
        ),
      );
      expect(find.text('3-day streak reward!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('next_step_action')));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(h.rewards.claims, [3]);
      expect(find.text('+20 coins collected!'), findsOneWidget);
      // Now everything is collected: all done, with the next streak reward ahead.
      expect(find.text('All goals done today!'), findsOneWidget);
      expect(find.textContaining('7-day streak reward'), findsOneWidget);
    });

    testWidgets('home card: all done has no button', (tester) async {
      await show(
        tester,
        goals: [
          model(
            'play_1',
            'Finish 1 game',
            target: 1,
            progress: 1,
            claimed: true,
          ),
        ],
      );
      expect(find.text('All goals done today!'), findsOneWidget);
      expect(find.byKey(const Key('next_step_action')), findsNothing);
    });

    testWidgets('home card: nothing from the server shows nothing', (
      tester,
    ) async {
      await show(tester, goals: const []);
      expect(find.byKey(const Key('next_step_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('result panel: says "Up next" and has no Play button', (
      tester,
    ) async {
      await show(
        tester,
        panel: true,
        goals: [
          model('play_3', 'Finish 3 games', target: 3, progress: 2, reward: 40),
        ],
      );
      expect(find.byKey(const Key('next_step_panel')), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Finish 3 games'), findsOneWidget);
      expect(find.textContaining('2 of 3'), findsWidgets);
      expect(
        find.byKey(const Key('next_step_action')),
        findsNothing,
        reason: 'the result screen already has Play again',
      );
    });

    testWidgets(
      'result panel: a goal this game finished can be collected right there',
      (tester) async {
        final h = await show(
          tester,
          panel: true,
          goals: [model('play_1', 'Finish 1 game', target: 1, progress: 1)],
        );
        expect(find.text('Collect +20 coins'), findsOneWidget);
        await tester.tap(find.byKey(const Key('next_step_action')));
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(h.goals.claims, ['play_1']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'result panel: with no provider scope it quietly shows nothing',
      (tester) async {
        await show(tester, goals: const [], panel: true, withScope: false);
        expect(find.byKey(const Key('next_step_panel')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _SignedIn extends AuthController {
  @override
  Future<AppUser?> build() async => const UserModel(
    id: 'mock-user-0',
    email: 'test@example.com',
    displayName: 'Test User',
  );
}

class _Harness {
  final _Goals goals;
  final _Rewards rewards;
  _Harness(this.goals, this.rewards);
}

/// A stand-in for the server's daily goals: "pays" a claim by marking it collected.
class _Goals implements DailyMissionDatasource {
  _Goals(this.goals);

  List<DailyMissionModel> goals;
  final claims = <String>[];

  @override
  Future<List<DailyMissionModel>> getTodayMissions(String userId) async =>
      goals;

  @override
  Future<DailyMissionModel> recordQuizCompleted(String userId) =>
      throw UnsupportedError('not used');

  @override
  Future<void> claimMission(String userId, String missionId) async {
    claims.add(missionId);
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

/// A stand-in for the server's streak rewards.
class _Rewards implements StreakRewardsRemoteDatasource {
  _Rewards(this.rewards);

  StreakRewards? rewards;
  final claims = <int>[];

  @override
  Future<StreakRewards?> fetch() async => rewards;

  @override
  Future<void> claim(int days) async {
    claims.add(days);
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

  @override
  Future<void> buyFreeze() async {}
}
