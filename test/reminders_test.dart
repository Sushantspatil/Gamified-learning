import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
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
import 'package:skillverse_app/features/reminders/application/reminders_controller.dart';
import 'package:skillverse_app/features/reminders/data/reminder_scheduler.dart';
import 'package:skillverse_app/features/reminders/domain/reminder_planner.dart';
import 'package:skillverse_app/features/reminders/presentation/reminder_settings_row.dart';
import 'package:skillverse_app/features/streaks/data/datasources/remote/streak_rewards_remote_datasource.dart';
import 'package:skillverse_app/features/streaks/data/datasources/streak_datasource.dart';
import 'package:skillverse_app/features/streaks/data/models/streak_model.dart';
import 'package:skillverse_app/features/streaks/domain/entities/streak_rewards.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_providers.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_rewards_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

/// Records what the app asks the phone to do.
class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.supported = true, this.grants = true});

  final bool supported;
  bool grants;
  int permissionRequests = 0;
  int cancels = 0;
  final scheduled = <List<ReminderPlan>>[];

  @override
  bool get isSupported => supported;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grants;
  }

  @override
  Future<void> replaceAll(List<ReminderPlan> plans) async =>
      scheduled.add(plans);
  @override
  Future<void> cancelAll() async => cancels++;
}

class _SignedInAuth extends AuthController {
  @override
  Future<AppUser?> build() async => const UserModel(
    id: 'mock-user-0',
    email: 'test@example.com',
    displayName: 'Test User',
  );
}

class _SignedOutAuth extends AuthController {
  @override
  Future<AppUser?> build() async => null;
}

class _StreakOf implements StreakDatasource {
  _StreakOf(this.days);
  final int days;
  @override
  Future<StreakModel> getStreak(String userId) async =>
      StreakModel(currentStreak: days, lastActiveDateKey: null);
  @override
  Future<StreakModel> recordAppOpen(String userId) => getStreak(userId);
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

class _NoStreakRewards implements StreakRewardsRemoteDatasource {
  @override
  Future<StreakRewards?> fetch() async => null;
  @override
  Future<void> claim(int days) async {}
  @override
  Future<void> buyFreeze() async {}
}

final _fixedNow = DateTime.utc(2026, 3, 10, 10);

Future<LocalStorageService> _storage([Map<String, Object> prefs = const {}]) {
  SharedPreferences.setMockInitialValues(prefs);
  return LocalStorageService.create();
}

Future<void> _showDashboard(
  WidgetTester tester, {
  required _FakeScheduler scheduler,
  required LocalStorageService storage,
  int streak = 3,
  bool signedIn = true,
}) async {
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
        if (signedIn)
          authControllerProvider.overrideWith(_SignedInAuth.new)
        else
          authControllerProvider.overrideWith(_SignedOutAuth.new),
        learningPathDatasourceProvider.overrideWithValue(
          LearningPathMockDatasource(),
        ),
        chapterDatasourceProvider.overrideWithValue(ChapterMockDatasource()),
        profileDatasourceProvider.overrideWithValue(ProfileMockDatasource()),
        streakDatasourceProvider.overrideWithValue(_StreakOf(streak)),
        walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
        dailyMissionDatasourceProvider.overrideWithValue(_NoGoals()),
        streakRewardsDatasourceProvider.overrideWithValue(_NoStreakRewards()),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderClockProvider.overrideWithValue(() => _fixedNow),
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

void main() {
  group('asking once', () {
    testWidgets('on a streak of two or more, the player is asked', (
      tester,
    ) async {
      final scheduler = _FakeScheduler();
      await _showDashboard(
        tester,
        scheduler: scheduler,
        storage: await _storage(),
      );
      expect(find.text('Protect your streak'), findsOneWidget);
      expect(scheduler.permissionRequests, 0, reason: 'asking is not enabling');
    });

    testWidgets(
      'Turn on asks the phone, saves the choice and plans reminders',
      (tester) async {
        final scheduler = _FakeScheduler();
        final storage = await _storage();
        await _showDashboard(tester, scheduler: scheduler, storage: storage);

        await tester.tap(find.byKey(const Key('reminder_prompt_turn_on')));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(scheduler.permissionRequests, 1);
        expect(storage.getBool('settings_reminders_enabled'), isTrue);
        expect(storage.getBool('settings_reminders_prompted'), isTrue);
        expect(find.text('Protect your streak'), findsNothing);
        // Planned from the 3-day streak, starting tomorrow.
        expect(scheduler.scheduled, isNotEmpty);
        final plans = scheduler.scheduled.last;
        expect(plans.first.title, 'Keep your 3-day streak alive');
        expect(plans.first.at.isAfter(_fixedNow), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Not now is remembered and nothing is scheduled', (
      tester,
    ) async {
      final scheduler = _FakeScheduler();
      final storage = await _storage();
      await _showDashboard(tester, scheduler: scheduler, storage: storage);

      await tester.tap(find.byKey(const Key('reminder_prompt_not_now')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(scheduler.permissionRequests, 0);
      expect(storage.getBool('settings_reminders_enabled'), isFalse);
      expect(storage.getBool('settings_reminders_prompted'), isTrue);
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets('a phone that refuses notifications leaves reminders off', (
      tester,
    ) async {
      final scheduler = _FakeScheduler(grants: false);
      final storage = await _storage();
      await _showDashboard(tester, scheduler: scheduler, storage: storage);

      await tester.tap(find.byKey(const Key('reminder_prompt_turn_on')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(storage.getBool('settings_reminders_enabled'), isFalse);
      expect(
        find.text(
          'Notifications are blocked. You can allow them in your phone settings.',
        ),
        findsOneWidget,
      );
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets('not asked again once the player has answered', (tester) async {
      await _showDashboard(
        tester,
        scheduler: _FakeScheduler(),
        storage: await _storage({'settings_reminders_prompted': true}),
      );
      expect(find.text('Protect your streak'), findsNothing);
    });

    testWidgets('not asked on a streak of one day', (tester) async {
      await _showDashboard(
        tester,
        scheduler: _FakeScheduler(),
        storage: await _storage(),
        streak: 1,
      );
      expect(find.text('Protect your streak'), findsNothing);
    });

    testWidgets('not asked on a device that cannot show reminders', (
      tester,
    ) async {
      await _showDashboard(
        tester,
        scheduler: _FakeScheduler(supported: false),
        storage: await _storage(),
      );
      expect(find.text('Protect your streak'), findsNothing);
    });

    testWidgets('not asked when nobody is signed in', (tester) async {
      await _showDashboard(
        tester,
        scheduler: _FakeScheduler(),
        storage: await _storage(),
        signedIn: false,
      );
      expect(find.text('Protect your streak'), findsNothing);
    });
  });

  group('keeping the schedule right', () {
    testWidgets('reminders on: the schedule follows the streak', (
      tester,
    ) async {
      final scheduler = _FakeScheduler();
      await _showDashboard(
        tester,
        scheduler: scheduler,
        storage: await _storage({
          'settings_reminders_enabled': true,
          'settings_reminders_prompted': true,
        }),
        streak: 9,
      );
      expect(scheduler.scheduled, isNotEmpty);
      expect(
        scheduler.scheduled.last.first.title,
        'Keep your 9-day streak alive',
      );
      expect(scheduler.scheduled.last.length, 3);
    });

    testWidgets(
      'reminders off: nothing is scheduled and old ones are cleared',
      (tester) async {
        final scheduler = _FakeScheduler();
        await _showDashboard(
          tester,
          scheduler: scheduler,
          storage: await _storage({'settings_reminders_prompted': true}),
        );
        expect(scheduler.scheduled, isEmpty);
        expect(scheduler.cancels, greaterThan(0));
      },
    );

    testWidgets('signed out: a phone with reminders left on goes quiet', (
      tester,
    ) async {
      final scheduler = _FakeScheduler();
      await _showDashboard(
        tester,
        scheduler: scheduler,
        storage: await _storage({
          'settings_reminders_enabled': true,
          'settings_reminders_prompted': true,
        }),
        signedIn: false,
      );
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancels, greaterThan(0));
    });

    testWidgets('a device that cannot show reminders is never touched', (
      tester,
    ) async {
      final scheduler = _FakeScheduler(supported: false);
      await _showDashboard(
        tester,
        scheduler: scheduler,
        storage: await _storage({'settings_reminders_enabled': true}),
      );
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancels, 0);
      expect(scheduler.permissionRequests, 0);
    });
  });

  group('the Profile switch', () {
    Future<void> showRow(
      WidgetTester tester,
      _FakeScheduler scheduler,
      LocalStorageService storage,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            reminderSchedulerProvider.overrideWithValue(scheduler),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ReminderSettingsRow()),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('is left out where reminders cannot work', (tester) async {
      await showRow(tester, _FakeScheduler(supported: false), await _storage());
      expect(find.byKey(const Key('reminders_switch')), findsNothing);
      expect(find.text('Daily Reminders'), findsNothing);
    });

    testWidgets('turns reminders on, then off', (tester) async {
      final scheduler = _FakeScheduler();
      final storage = await _storage();
      await showRow(tester, scheduler, storage);

      expect(find.text('Daily Reminders'), findsOneWidget);
      var switchWidget = tester.widget<Switch>(
        find.byKey(const Key('reminders_switch')),
      );
      expect(switchWidget.value, isFalse);

      await tester.tap(find.byKey(const Key('reminders_switch')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scheduler.permissionRequests, 1);
      expect(storage.getBool('settings_reminders_enabled'), isTrue);
      switchWidget = tester.widget<Switch>(
        find.byKey(const Key('reminders_switch')),
      );
      expect(switchWidget.value, isTrue);

      await tester.tap(find.byKey(const Key('reminders_switch')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(storage.getBool('settings_reminders_enabled'), isFalse);
      expect(scheduler.cancels, 1);
    });

    testWidgets('stays off and explains when the phone says no', (
      tester,
    ) async {
      final scheduler = _FakeScheduler(grants: false);
      final storage = await _storage();
      await showRow(tester, scheduler, storage);

      await tester.tap(find.byKey(const Key('reminders_switch')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(storage.getBool('settings_reminders_enabled'), isFalse);
      expect(
        tester.widget<Switch>(find.byKey(const Key('reminders_switch'))).value,
        isFalse,
      );
      expect(find.textContaining('Notifications are blocked'), findsOneWidget);
    });
  });
}
