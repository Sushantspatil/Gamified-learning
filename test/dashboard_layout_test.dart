import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/chapters/data/datasources/mock/chapter_mock_datasource.dart';
import 'package:skillverse_app/features/chapters/presentation/providers/chapter_providers.dart';
import 'package:skillverse_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:skillverse_app/features/learning_paths/data/datasources/mock/learning_path_mock_datasource.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/profile/data/datasources/mock/profile_mock_datasource.dart';
import 'package:skillverse_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:skillverse_app/features/streaks/data/datasources/mock/streak_mock_datasource.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

/// The dashboard lays out at phone sizes (also with large text) without
/// overflow, shows the coin balance, and runs its subjects row edge to edge.
Future<void> _show(
  WidgetTester tester, {
  double textScale = 1,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await LocalStorageService.create();
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(path: '/wallet', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/practice',
        builder: (_, state) =>
            Scaffold(body: Text('PLAY ${state.uri}', key: const Key('play'))),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        learningPathDatasourceProvider.overrideWithValue(
          LearningPathMockDatasource(),
        ),
        chapterDatasourceProvider.overrideWithValue(ChapterMockDatasource()),
        profileDatasourceProvider.overrideWithValue(ProfileMockDatasource()),
        streakDatasourceProvider.overrideWithValue(StreakMockDatasource()),
        walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('dashboard lays out without overflow (text x$scale)', (
      tester,
    ) async {
      await _show(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      // coins, streak and gems sit side by side in the header
      expect(find.byTooltip('Wallet'), findsOneWidget);
      expect(find.byTooltip('Shop'), findsOneWidget);
      expect(find.byKey(const Key('mascot_play')), findsOneWidget);
      // no path chosen: a clear next step, not an empty message
      expect(find.byKey(const Key('choose_path_card')), findsOneWidget);
      expect(find.text('No learning path selected.'), findsNothing);

      // scroll through the whole page: nothing overflows on the way
      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(const Offset(180, 600), const Offset(0, -350));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('the subjects row runs from edge to edge', (tester) async {
    await _show(tester);
    await tester.dragUntilVisible(
      find.text('Your subjects'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final row = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    );
    expect(row, findsOneWidget);
    final box = tester.getRect(row);
    expect(box.left, 0);
    expect(box.right, 360);
    expect(tester.takeException(), isNull);
  });
  for (final sudden in [false, true]) {
    testWidgets(
      '${sudden ? 'Sudden death' : 'Quick quiz'} opens the Play screen',
      (tester) async {
        await _show(
          tester,
          prefs: {StorageKeys.selectedLearningPathId: 'accounting'},
        );
        await tester.dragUntilVisible(
          find.text(sudden ? 'Sudden death' : 'Quick quiz'),
          find.byType(ListView).first,
          const Offset(0, -200),
        );
        await tester.tap(find.text(sudden ? 'Sudden death' : 'Quick quiz'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final shown = tester.widget<Text>(find.byKey(const Key('play'))).data!;
        expect(shown, contains('subjectId=accounting'));
        expect(shown.contains('quizType=suddenDeath'), sudden);
      },
    );
  }
}
