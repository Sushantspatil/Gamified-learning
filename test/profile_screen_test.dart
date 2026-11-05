import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/learning_paths/data/datasources/mock/learning_path_mock_datasource.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/profile/data/datasources/mock/profile_mock_datasource.dart';
import 'package:skillverse_app/features/profile/presentation/achievements.dart';
import 'package:skillverse_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:skillverse_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';
import 'package:skillverse_app/features/streaks/data/datasources/mock/streak_mock_datasource.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

class _SignedIn extends AuthController {
  @override
  Future<AppUser?> build() async => const AppUser(
    id: 'mock-user-0',
    email: 'ada@example.com',
    displayName: 'Ada',
  );
}

late LocalStorageService _storage;

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_storage),
      authControllerProvider.overrideWith(_SignedIn.new),
      profileDatasourceProvider.overrideWithValue(ProfileMockDatasource()),
      streakDatasourceProvider.overrideWithValue(StreakMockDatasource()),
      walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
      learningPathDatasourceProvider.overrideWithValue(
        LearningPathMockDatasource(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _show(
  WidgetTester tester,
  ProviderContainer container, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ProfileScreen(),
      ),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.create();
  });

  group('achievements', () {
    test('start locked and unlock as the numbers grow', () {
      final none = computeAchievements(const AchievementInputs());
      expect(none.where((a) => a.unlocked), isEmpty);

      final some = computeAchievements(
        const AchievementInputs(
          gamesPlayed: 12,
          streak: 7,
          level: 9,
          hasSpun: true,
          cosmeticsOwned: 1,
        ),
      );
      final unlocked = {for (final a in some) a.id: a.unlocked};
      expect(unlocked['first_game'], isTrue);
      expect(unlocked['ten_games'], isTrue);
      expect(unlocked['fifty_games'], isFalse);
      expect(unlocked['streak_3'], isTrue);
      expect(unlocked['streak_7'], isTrue);
      expect(unlocked['streak_30'], isFalse);
      expect(unlocked['level_5'], isTrue);
      expect(unlocked['level_10'], isFalse); // level 9 of 10
      expect(unlocked['first_spin'], isTrue);
      expect(unlocked['first_cosmetic'], isTrue);
      expect(unlocked['three_cosmetics'], isFalse);
    });

    test('progress never runs past the target', () {
      final badge = computeAchievements(
        const AchievementInputs(gamesPlayed: 400),
      ).firstWhere((a) => a.id == 'ten_games');
      expect(badge.progress, 1);
      expect(badge.progressLabel, '10 / 10');
      final partial = computeAchievements(
        const AchievementInputs(streak: 2),
      ).firstWhere((a) => a.id == 'streak_3');
      expect(partial.progressLabel, '2 / 3');
      expect(partial.progress, closeTo(2 / 3, 1e-9));
    });
  });

  group('Profile screen', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('shows everything and fits (text x$scale)', (tester) async {
        await _show(tester, _container(), textScale: scale);

        expect(find.byKey(const Key('profile_hero')), findsOneWidget);
        expect(find.text('Ada'), findsOneWidget);
        expect(find.byTooltip('Edit Profile'), findsOneWidget);
        expect(find.text('Day streak'), findsOneWidget);
        expect(find.text('Coins'), findsOneWidget);
        expect(find.text('Gems'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // The page builds lazily: scroll to the bottom, checking as we go.
        for (var i = 0; i < 8; i++) {
          await tester.dragFrom(const Offset(180, 600), const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Cosmetics'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
        expect(find.text('ada@example.com'), findsOneWidget);
      });
    }

    testWidgets('a badge opens its detail with how to earn it', (tester) async {
      await _show(tester, _container());
      await tester.ensureVisible(find.text('Week Warrior'));
      await tester.pump();
      await tester.tap(find.text('Week Warrior'));
      await tester.pumpAndSettle();
      expect(find.text('Play 7 days in a row.'), findsOneWidget);
    });

    testWidgets('a newly unlocked badge is announced once', (tester) async {
      final container = _container();
      container.read(rewardsProvider.notifier).recordQuizCompleted('game-1');

      await _show(tester, container);
      expect(find.text('New badge unlocked: First Steps!'), findsOneWidget);

      // Leaving and coming back does not repeat it.
      await tester.pumpWidget(const SizedBox());
      await _show(tester, container);
      expect(find.text('New badge unlocked: First Steps!'), findsNothing);
    });

    testWidgets('logging out asks first', (tester) async {
      await _show(tester, _container());
      await tester.ensureVisible(find.text('Logout'));
      await tester.pump();
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsNothing);
    });
  });
}
