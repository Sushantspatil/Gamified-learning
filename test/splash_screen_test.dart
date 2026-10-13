import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/app/app.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/chapters/data/datasources/mock/chapter_mock_datasource.dart';
import 'package:skillverse_app/features/chapters/presentation/providers/chapter_providers.dart';
import 'package:skillverse_app/features/learning_paths/data/datasources/mock/learning_path_mock_datasource.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/profile/data/datasources/mock/profile_mock_datasource.dart';
import 'package:skillverse_app/features/profile/data/datasources/profile_datasource.dart';
import 'package:skillverse_app/features/profile/data/models/user_profile_model.dart';
import 'package:skillverse_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:skillverse_app/features/questions/data/datasources/mock/question_mock_datasource.dart';
import 'package:skillverse_app/features/questions/presentation/providers/question_providers.dart';
import 'package:skillverse_app/features/quiz/data/datasources/mock/quiz_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:skillverse_app/features/splash/presentation/widgets/splash_loading_bar.dart';
import 'package:skillverse_app/features/splash/presentation/widgets/splash_particles.dart';
import 'package:skillverse_app/features/streaks/data/datasources/mock/streak_mock_datasource.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

class _CustomProfileMockDatasource extends ProfileMockDatasource {
  final UserProfileModel profile;

  _CustomProfileMockDatasource(this.profile);

  @override
  Future<UserProfileModel> getProfile(String userId) async => profile;
}

Future<void> _pumpAppWithValues(
  WidgetTester tester, {
  Map<String, Object> values = const {},
  ProfileDatasource? profileDatasource,
}) async {
  SharedPreferences.setMockInitialValues(values);
  final storageService = await LocalStorageService.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storageService),
        authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        learningPathDatasourceProvider.overrideWithValue(
          LearningPathMockDatasource(),
        ),
        chapterDatasourceProvider.overrideWithValue(
          ChapterMockDatasource(),
        ),
        questionDatasourceProvider.overrideWithValue(QuestionMockDatasource()),
        quizDatasourceProvider.overrideWithValue(QuizMockDatasource()),
        if (profileDatasource != null)
          profileDatasourceProvider.overrideWithValue(profileDatasource),
        streakDatasourceProvider.overrideWithValue(StreakMockDatasource()),
        walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
      ],
      child: const SkillverseApp(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen UI & Widgets', () {
    testWidgets('SplashScreen renders full screen with artwork, loading bar, and text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Verify splash screen widget exists
      expect(find.byType(SplashScreen), findsOneWidget);

      // Verify artwork asset is present
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      expect(
        (imageWidget.image as AssetImage).assetName,
        'assets/images/splash/skillverse_splash.png',
      );

      // Verify animated loading indicator
      expect(find.byType(SplashLoadingBar), findsOneWidget);

      // Verify adventure text
      expect(find.text('Loading your adventure...'), findsOneWidget);

      // Verify ambient particles overlay
      expect(find.byType(SplashParticlesOverlay), findsOneWidget);

      // Advance animation slightly and verify stable render
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Loading your adventure...'), findsOneWidget);
    });

    testWidgets('SplashLoadingBar renders correct visual progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SplashLoadingBar(progress: 0.5, width: 250, height: 16),
            ),
          ),
        ),
      );

      expect(find.byType(SplashLoadingBar), findsOneWidget);
      final barFinder = find.byType(SplashLoadingBar);
      expect(barFinder, findsOneWidget);

      final barWidget = tester.widget<SplashLoadingBar>(barFinder);
      expect(barWidget.progress, 0.5);
      expect(barWidget.width, 250);
      expect(barWidget.height, 16);
    });

    testWidgets('SplashScreen disposes all controllers cleanly on unmount', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Replace with another widget to trigger dispose()
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Replaced')),
        ),
      );

      await tester.pump();
      expect(find.text('Replaced'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });

  group('Startup Routing Integration', () {
    testWidgets('Unauthenticated user starts on splash and routes to login after splash duration', (
      tester,
    ) async {
      await _pumpAppWithValues(tester, values: {});

      // Initially on SplashScreen
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Loading your adventure...'), findsOneWidget);

      // Advance through splash minimum duration and settle
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Now routed to Login screen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Log in to continue your streak.'), findsOneWidget);
    });

    testWidgets('Authenticated user with profile routes from splash to dashboard', (
      tester,
    ) async {
      const completedProfile = UserProfileModel(
        avatarId: 'robot',
        classLevel: '12th',
        board: 'Maharashtra State Board',
        selectedSubjectIds: ['web-dev'],
        profileSetupCompleted: true,
        tutorialCompleted: true,
        xp: 0,
        level: 1,
      );

      await _pumpAppWithValues(
        tester,
        values: {
          'current_user_id': 'mock-user-0',
          'selected_learning_path_id': 'web-dev',
        },
        profileDatasource: _CustomProfileMockDatasource(completedProfile),
      );

      // Initially on SplashScreen
      expect(find.byType(SplashScreen), findsOneWidget);

      // Settle past splash minimum duration and let async data load
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Splash is gone, Dashboard is visible
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    });

    testWidgets('Authenticated user without profile setup routes to onboarding', (
      tester,
    ) async {
      const incompleteProfile = UserProfileModel(
        avatarId: 'default',
        selectedSubjectIds: ['web-dev'],
        profileSetupCompleted: false,
        tutorialCompleted: false,
        xp: 0,
        level: 1,
      );

      await _pumpAppWithValues(
        tester,
        values: {
          'current_user_id': 'mock-user-0',
        },
        profileDatasource: _CustomProfileMockDatasource(incompleteProfile),
      );

      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Routed to Profile Setup
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Choose Your Avatar'), findsOneWidget);
    });

    testWidgets('Splash is removed from navigation back stack once routed away', (
      tester,
    ) async {
      await _pumpAppWithValues(tester, values: {});

      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify on Login
      expect(find.text('Log in to continue your streak.'), findsOneWidget);

      // Back navigation should not return to splash
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(navigatorState.canPop(), isFalse);
    });
  });
}
