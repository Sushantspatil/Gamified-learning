import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/motion/app_motion.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:skillverse_app/features/splash/presentation/widgets/splash_particles.dart';
import 'package:skillverse_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppMotion.reduceMotion & accessibleNavigation flag decoupling', () {
    testWidgets(
      'disableAnimations: false, accessibleNavigation: false -> normal animations remain enabled',
      (tester) async {
        late bool reduceMotionResult;
        late bool accessibleNavResult;
        late Duration computedDuration;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: false,
                accessibleNavigation: false,
              ),
              child: Builder(
                builder: (context) {
                  reduceMotionResult = AppMotion.reduceMotion(context);
                  accessibleNavResult = AppMotion.accessibleNavigation(context);
                  computedDuration = AppMotion.duration(
                    context,
                    const Duration(milliseconds: 300),
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(reduceMotionResult, isFalse);
        expect(accessibleNavResult, isFalse);
        expect(computedDuration, const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'disableAnimations: false, accessibleNavigation: true -> animations are not disabled solely because of accessible navigation',
      (tester) async {
        late bool reduceMotionResult;
        late bool accessibleNavResult;
        late Duration computedDuration;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: false,
                accessibleNavigation: true, // E.g., TalkBack active on Samsung device
              ),
              child: Builder(
                builder: (context) {
                  reduceMotionResult = AppMotion.reduceMotion(context);
                  accessibleNavResult = AppMotion.accessibleNavigation(context);
                  computedDuration = AppMotion.duration(
                    context,
                    const Duration(milliseconds: 300),
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Crucial fix: accessibleNavigation must NOT suppress animations!
        expect(reduceMotionResult, isFalse);
        expect(accessibleNavResult, isTrue);
        expect(computedDuration, const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'disableAnimations: true, accessibleNavigation: false -> genuine reduced motion request is respected',
      (tester) async {
        late bool reduceMotionResult;
        late bool accessibleNavResult;
        late Duration computedDuration;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                accessibleNavigation: false,
              ),
              child: Builder(
                builder: (context) {
                  reduceMotionResult = AppMotion.reduceMotion(context);
                  accessibleNavResult = AppMotion.accessibleNavigation(context);
                  computedDuration = AppMotion.duration(
                    context,
                    const Duration(milliseconds: 300),
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(reduceMotionResult, isTrue);
        expect(accessibleNavResult, isFalse);
        expect(computedDuration, Duration.zero);
      },
    );

    testWidgets(
      'disableAnimations: true, accessibleNavigation: true -> reduced motion takes precedence',
      (tester) async {
        late bool reduceMotionResult;
        late bool accessibleNavResult;
        late Duration computedDuration;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                accessibleNavigation: true,
              ),
              child: Builder(
                builder: (context) {
                  reduceMotionResult = AppMotion.reduceMotion(context);
                  accessibleNavResult = AppMotion.accessibleNavigation(context);
                  computedDuration = AppMotion.duration(
                    context,
                    const Duration(milliseconds: 300),
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(reduceMotionResult, isTrue);
        expect(accessibleNavResult, isTrue);
        expect(computedDuration, Duration.zero);
      },
    );

    testWidgets(
      'Changing accessibility settings dynamically does not leave animations in an invalid state',
      (tester) async {
        bool disableAnimations = false;
        bool accessibleNavigation = true;

        Widget buildApp() {
          return MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: disableAnimations,
                accessibleNavigation: accessibleNavigation,
              ),
              child: const SplashScreen(),
            ),
          );
        }

        // 1. Initial state: TalkBack active on Samsung (accessibleNavigation: true, disableAnimations: false)
        await tester.pumpWidget(buildApp());
        await tester.pump(const Duration(milliseconds: 100));

        // Splash particles must be rendered because animations are NOT disabled!
        expect(find.byType(SplashParticlesOverlay), findsOneWidget);

        // 2. User turns on "Remove animations" in Android settings
        disableAnimations = true;
        await tester.pumpWidget(buildApp());
        await tester.pump(const Duration(milliseconds: 100));

        // Particles now omitted due to genuine reduce-motion
        expect(find.byType(SplashParticlesOverlay), findsNothing);

        // 3. User turns off "Remove animations" again
        disableAnimations = false;
        await tester.pumpWidget(buildApp());
        await tester.pump(const Duration(milliseconds: 100));

        // Ambient animations cleanly resume without crash or invalid state
        expect(find.byType(SplashParticlesOverlay), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Animation Component Compatibility with Samsung/TalkBack settings', () {
    testWidgets(
      'SplashScreen renders ambient animations when accessibleNavigation is true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MediaQuery(
              data: MediaQueryData(
                disableAnimations: false,
                accessibleNavigation: true,
              ),
              child: SplashScreen(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(SplashParticlesOverlay), findsOneWidget);
        expect(find.text('Loading your adventure...'), findsOneWidget);
      },
    );

    testWidgets(
      'LoginScreen initializes and runs ambient controller when accessibleNavigation is true',
      (tester) async {
        final storage = await LocalStorageService.create();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(storage),
              authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  disableAnimations: false,
                  accessibleNavigation: true,
                ),
                child: LoginScreen(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Welcome back'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'QuizCelebrationOverlay plays celebration when accessibleNavigation is true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MediaQuery(
              data: MediaQueryData(
                disableAnimations: false,
                accessibleNavigation: true,
              ),
              child: QuizCelebrationOverlay(
                child: Text('Quiz Completed!'),
              ),
            ),
          ),
        );

        // Advance frames past postFrameCallback
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Quiz Completed!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
