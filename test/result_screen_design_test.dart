import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/models/user_model.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/daily_missions/data/datasources/daily_mission_datasource.dart';
import 'package:skillverse_app/features/daily_missions/data/models/daily_mission_model.dart';
import 'package:skillverse_app/features/daily_missions/presentation/providers/daily_mission_providers.dart';
import 'package:skillverse_app/features/habit/domain/next_step.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_result.dart';
import 'package:skillverse_app/features/quiz/domain/personal_best.dart';
import 'package:skillverse_app/features/quiz/domain/result_flow.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_result_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/result/result_share.dart';
import 'package:skillverse_app/features/streaks/data/datasources/remote/streak_rewards_remote_datasource.dart';
import 'package:skillverse_app/features/streaks/domain/entities/streak_rewards.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_rewards_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

QuizResult _game({
  required int correct,
  int total = 10,
  int points = 50,
  bool endedEarly = false,
  int xp = 35,
  int coins = 15,
  bool withLevel = false,
  Duration time = const Duration(minutes: 1, seconds: 42),
}) => QuizResult(
  sessionId: 'session-$correct-$points',
  topicId: 'topic-1',
  quizType: QuestionType.mcq,
  score: Score(
    earnedPoints: points,
    maxPoints: endedEarly ? 0 : 100,
    correctCount: correct,
    totalCount: total,
  ),
  records: const [],
  endedEarly: endedEarly,
  streakCount: 0,
  xpAwarded: xp,
  coinsAwarded: coins,
  rewardBreakdown: const QuizRewardBreakdown(
    score: [RewardBreakdownItem(key: 'correct_answer_points', amount: 50)],
    xp: [RewardBreakdownItem(key: 'completion_xp', amount: 10)],
    coins: [RewardBreakdownItem(key: 'completion_coins', amount: 5)],
  ),
  levelProgress: withLevel
      ? const QuizLevelProgress(
          currentLevel: 4,
          experience: 340,
          nextLevelExperience: 500,
        )
      : null,
  timeTaken: time,
  createdAt: DateTime(2026),
);

DailyMissionModel _goal(
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

class _SignedIn extends AuthController {
  @override
  Future<AppUser?> build() async => const UserModel(
    id: 'mock-user-0',
    email: 'test@example.com',
    displayName: 'Test User',
  );
}

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
            claimed: true,
          )
        else
          g,
    ];
  }
}

class _NoRewards implements StreakRewardsRemoteDatasource {
  @override
  Future<StreakRewards?> fetch() async => null;
  @override
  Future<void> claim(int days) async {}
  @override
  Future<void> buyFreeze() async {}
}

/// Shows a result. With [goals] the app's providers are available (so the goals
/// part can load); without them there is no provider scope at all.
Future<_Goals?> _show(
  WidgetTester tester,
  QuizResult result, {
  VoidCallback? onPlayAgain,
  VoidCallback? onDone,
  LocalStorageService? storage,
  List<DailyMissionModel>? goals,
  bool leveledUp = false,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: QuizResultView(
        result: result,
        onDone: onDone ?? () {},
        onPlayAgain: onPlayAgain,
        leveledUp: leveledUp,
      ),
    ),
  );
  _Goals? fake;
  Widget root = app;
  if (goals != null || storage != null) {
    fake = _Goals(goals ?? const []);
    root = ProviderScope(
      overrides: [
        if (storage != null)
          localStorageServiceProvider.overrideWithValue(storage),
        if (goals != null) ...[
          authControllerProvider.overrideWith(_SignedIn.new),
          dailyMissionDatasourceProvider.overrideWithValue(fake),
          streakRewardsDatasourceProvider.overrideWithValue(_NoRewards()),
          walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
        ],
      ],
      child: app,
    );
  }
  await tester.pumpWidget(root);
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _tapPrimary(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('result_primary')));
  await tester.pumpAndSettle();
}

/// The score is one big number with "/ 100 pts" (or "points") next to it.
void _expectPoints(int points, String unit) {
  final row = find.byKey(const Key('result_points'));
  expect(
    find.descendant(of: row, matching: find.text('$points')),
    findsOneWidget,
  );
  expect(find.descendant(of: row, matching: find.text(unit)), findsOneWidget);
}

void main() {
  group('the summary screen', () {
    testWidgets('a good game: headline, points, three tiles and coins', (
      tester,
    ) async {
      await _show(tester, _game(correct: 7, points: 70));
      expect(find.byKey(const Key('result_summary')), findsOneWidget);
      expect(find.text('Great job!'), findsOneWidget);
      _expectPoints(70, '/ 100 pts');
      expect(find.byKey(const Key('result_tiles')), findsOneWidget);
      expect(find.text('XP'), findsOneWidget);
      expect(find.text('+35'), findsOneWidget);
      expect(find.text('ACCURACY'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('1:42'), findsOneWidget);
      expect(find.text('+15 Coins'), findsOneWidget);
    });

    testWidgets('the headline uses the signed-in player\'s first name', (
      tester,
    ) async {
      await _show(tester, _game(correct: 7, points: 70), goals: const []);
      expect(find.text('Great job, Test!'), findsOneWidget);
    });

    testWidgets('no stars and no stacked reward blocks', (tester) async {
      await _show(tester, _game(correct: 7));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      expect(
        find.text('Score details'),
        findsOneWidget,
        reason: 'only as a small button, the breakdown is not on this screen',
      );
      expect(find.text('Quiz completion'), findsNothing);
    });

    testWidgets('a perfect game is brilliant', (tester) async {
      await _show(tester, _game(correct: 10, points: 100));
      expect(find.text('Brilliant!'), findsOneWidget);
    });

    testWidgets('nothing right is encouraging, not harsh', (tester) async {
      await _show(tester, _game(correct: 0, points: 0));
      expect(find.text('Keep going!'), findsOneWidget);
      expect(find.text('Every game makes you sharper'), findsOneWidget);
    });

    testWidgets('Sudden Death shows how many were right instead of accuracy', (
      tester,
    ) async {
      await _show(
        tester,
        _game(correct: 7, total: 8, points: 70, endedEarly: true),
      );
      expect(find.text('Nice run!'), findsOneWidget);
      expect(find.text('You got 7 right before it ended'), findsOneWidget);
      expect(find.text('CORRECT'), findsOneWidget);
      expect(find.text('ACCURACY'), findsNothing);
      _expectPoints(70, 'points');
    });
  });

  group('the buttons', () {
    testWidgets(
      'with a replay: Play again is the main button, Done the quiet one',
      (tester) async {
        var again = 0;
        var done = 0;
        await _show(
          tester,
          _game(correct: 5),
          onPlayAgain: () => again++,
          onDone: () => done++,
        );
        expect(find.text('Play again'), findsOneWidget);
        await tester.tap(find.byKey(const Key('result_primary')));
        expect(again, 1);
        await tester.tap(find.byKey(const Key('result_secondary')));
        expect(done, 1);
      },
    );

    testWidgets('without a replay Done is the main button', (tester) async {
      var done = 0;
      await _show(tester, _game(correct: 5), onDone: () => done++);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Play again'), findsNothing);
      expect(find.byKey(const Key('result_secondary')), findsNothing);
      await tester.tap(find.byKey(const Key('result_primary')));
      expect(done, 1);
    });

    testWidgets('the bar stays put while the page scrolls', (tester) async {
      await _show(tester, _game(correct: 5), onPlayAgain: () {});
      final before = tester.getTopLeft(find.byKey(const Key('result_primary')));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('result_primary'))),
        before,
      );
    });

    testWidgets('there are share and score-details buttons', (tester) async {
      await _show(tester, _game(correct: 5));
      expect(find.byKey(const Key('result_share')), findsOneWidget);
      expect(find.byKey(const Key('result_details_button')), findsOneWidget);
    });

    testWidgets('score details opens the breakdown in a sheet', (tester) async {
      await _show(tester, _game(correct: 5));
      await tester.tap(find.byKey(const Key('result_details_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('result_details_sheet')), findsOneWidget);
      expect(find.text('Quiz completion'), findsWidgets);
      expect(find.text('How scoring works'), findsOneWidget);
    });
  });

  group('the progress screen', () {
    testWidgets(
      'a goal that moved adds a second screen, reached with Continue',
      (tester) async {
        await _show(
          tester,
          _game(correct: 5),
          onPlayAgain: () {},
          goals: [
            _goal(
              'play_3',
              'Finish 3 games',
              target: 3,
              progress: 2,
              reward: 40,
            ),
          ],
        );
        // First screen: Continue, not Play again.
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Play again'), findsNothing);
        expect(find.byKey(const Key('result_progress')), findsNothing);

        await _tapPrimary(tester);

        // Second screen: the goal ring and next step, and now the final buttons.
        expect(find.byKey(const Key('result_progress')), findsOneWidget);
        expect(find.byKey(const Key('result_summary')), findsNothing);
        expect(find.byKey(const Key('daily_ring')), findsOneWidget);
        expect(find.text('Finish 3 games'), findsOneWidget);
        expect(find.text('Play again'), findsOneWidget);
        expect(find.text('Continue'), findsNothing);
      },
    );

    testWidgets('a finished goal is collected on the progress screen', (
      tester,
    ) async {
      final fake = await _show(
        tester,
        _game(correct: 5),
        onPlayAgain: () {},
        goals: [_goal('play_1', 'Finish 1 game', target: 1, progress: 1)],
      );
      await _tapPrimary(tester);
      expect(find.text('Goal complete!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('next_step_action')));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(fake!.claims, ['play_1']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all goals done and no level-up: no second screen at all', (
      tester,
    ) async {
      await _show(
        tester,
        _game(correct: 5),
        onPlayAgain: () {},
        goals: [
          _goal(
            'play_1',
            'Finish 1 game',
            target: 1,
            progress: 1,
            claimed: true,
          ),
        ],
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
    });

    testWidgets('a level-up gets the progress screen with its XP bar', (
      tester,
    ) async {
      await _show(
        tester,
        _game(correct: 5, withLevel: true),
        onPlayAgain: () {},
        leveledUp: true,
        goals: [
          _goal(
            'play_1',
            'Finish 1 game',
            target: 1,
            progress: 1,
            claimed: true,
          ),
        ],
      );
      expect(find.text('Continue'), findsOneWidget);
      await _tapPrimary(tester);
      expect(find.text('Level up!'), findsOneWidget);
      expect(find.text('Level 4'), findsOneWidget);
      expect(find.text('340 / 500 XP'), findsOneWidget);
      expect(find.text('+35 XP'), findsOneWidget);
    });

    testWidgets('without goals from the server there is no second screen', (
      tester,
    ) async {
      await _show(
        tester,
        _game(correct: 5),
        onPlayAgain: () {},
        goals: const [],
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
    });
  });

  group('personal best', () {
    Future<LocalStorageService> storage([Map<String, Object> v = const {}]) {
      SharedPreferences.setMockInitialValues(v);
      return LocalStorageService.create();
    }

    testWidgets('the first game sets a mark but is not "a new best"', (
      tester,
    ) async {
      final s = await storage();
      await _show(tester, _game(correct: 5, points: 50), storage: s);
      expect(find.byKey(const Key('personal_best_new')), findsNothing);
      expect(find.byKey(const Key('personal_best_line')), findsNothing);
      expect(s.getInt('best_score_mcq'), 50);
    });

    testWidgets('beating the best says so and saves it', (tester) async {
      final s = await storage({'best_score_mcq': 40});
      await _show(tester, _game(correct: 5, points: 50), storage: s);
      expect(find.text('New personal best!'), findsOneWidget);
      expect(s.getInt('best_score_mcq'), 50);
    });

    testWidgets('a lower score shows the best to beat and keeps it', (
      tester,
    ) async {
      final s = await storage({'best_score_mcq': 90});
      await _show(tester, _game(correct: 5, points: 50), storage: s);
      expect(find.text('Your best: 90'), findsOneWidget);
      expect(s.getInt('best_score_mcq'), 90);
    });

    testWidgets('Sudden Death keeps its own best', (tester) async {
      final s = await storage({'best_score_mcq': 90});
      await _show(
        tester,
        _game(correct: 3, total: 4, points: 30, endedEarly: true),
        storage: s,
      );
      expect(s.getInt('best_score_sudden_death'), 30);
      expect(s.getInt('best_score_mcq'), 90);
    });

    testWidgets('with no storage it quietly shows nothing', (tester) async {
      await _show(tester, _game(correct: 5));
      expect(find.byKey(const Key('personal_best_new')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('updateBest', () {
    test('no earlier score: nothing to beat; a zero is not remembered', () {
      expect(updateBest(score: 40).isNewBest, isFalse);
      expect(updateBest(score: 40).shouldSave, isTrue);
      expect(updateBest(score: 0).shouldSave, isFalse);
    });

    test('beating, tying and missing the best', () {
      final beat = updateBest(previous: 40, score: 41);
      expect((beat.isNewBest, beat.best, beat.shouldSave), (true, 41, true));
      final tie = updateBest(previous: 40, score: 40);
      expect((tie.isNewBest, tie.best, tie.shouldSave), (false, 40, false));
      final miss = updateBest(previous: 40, score: 10);
      expect((miss.isNewBest, miss.best, miss.shouldSave), (false, 40, false));
    });
  });

  group('resultNeedsProgressBeat', () {
    final goal = DailyMissionModel(
      id: 'g',
      title: 'Finish 1 game',
      targetCount: 1,
      progressCount: 0,
      coinReward: 20,
    );

    test('a level-up always gets one', () {
      expect(resultNeedsProgressBeat(leveledUp: true), isTrue);
      expect(
        resultNeedsProgressBeat(leveledUp: true, step: const AllGoalsDone()),
        isTrue,
      );
    });

    test('a goal that moved or can be collected gets one', () {
      expect(
        resultNeedsProgressBeat(
          leveledUp: false,
          step: ContinueGoal(goal, goalsDone: 0, goalsTotal: 1),
        ),
        isTrue,
      );
      expect(
        resultNeedsProgressBeat(
          leveledUp: false,
          step: CollectGoal(goal, readyCount: 1),
        ),
        isTrue,
      );
    });

    test('nothing new: none', () {
      expect(resultNeedsProgressBeat(leveledUp: false), isFalse);
      expect(
        resultNeedsProgressBeat(leveledUp: false, step: const AllGoalsDone()),
        isFalse,
      );
    });
  });

  group('formatResultTime', () {
    test('minutes and padded seconds', () {
      expect(formatResultTime(const Duration(seconds: 7)), '0:07');
      expect(formatResultTime(const Duration(minutes: 1, seconds: 42)), '1:42');
      expect(
        formatResultTime(const Duration(minutes: 12, seconds: 3)),
        '12:03',
      );
      expect(formatResultTime(Duration.zero), '0:00');
    });

    test('a negative time is shown as zero', () {
      expect(formatResultTime(const Duration(seconds: -5)), '0:00');
    });
  });

  group('the share message', () {
    test('names the score and the mode', () {
      expect(
        shareMessage(modeName: 'the MCQ Quiz', score: 30, maxScore: 100),
        'I scored 30/100 in the MCQ Quiz on SkillVerse! Can you beat me?',
      );
    });

    test('no maximum is left out', () {
      expect(
        shareMessage(modeName: 'Sudden Death', score: 70),
        'I scored 70 in Sudden Death on SkillVerse! Can you beat me?',
      );
      expect(
        shareMessage(modeName: 'x', score: 5, maxScore: 0),
        'I scored 5 in x on SkillVerse! Can you beat me?',
      );
    });
  });
}
