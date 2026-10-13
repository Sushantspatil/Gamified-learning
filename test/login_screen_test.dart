import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/authentication/presentation/screens/login_screen.dart';

Widget _createTestLoginApp({
  GoRouter? customRouter,
}) {
  final router = customRouter ??
      GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/signup',
            builder: (context, state) => const Scaffold(body: Text('Sign Up Screen')),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Scaffold(body: Text('Dashboard Screen')),
          ),
        ],
      );

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.darkTheme,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await LocalStorageService.create();
  });

  testWidgets('LoginScreen renders core UI elements correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storageService),
          authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        ],
        child: _createTestLoginApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in to continue your learning adventure.'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text("Don't have an account? Sign up"), findsOneWidget);
  });

  testWidgets('Email and password input fields accept text and toggle visibility', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storageService),
          authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        ],
        child: _createTestLoginApp(),
      ),
    );

    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));

    // Enter email
    await tester.enterText(textFields.first, 'student@skillverse.dev');
    expect(find.text('student@skillverse.dev'), findsOneWidget);

    // Enter password
    await tester.enterText(textFields.last, 'secret123');
    expect(find.text('secret123'), findsOneWidget);

    // Toggle password visibility eye icon
    final eyeButton = find.byTooltip('Show password');
    expect(eyeButton, findsOneWidget);
    await tester.tap(eyeButton);
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('Validation shows errors for empty or invalid inputs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storageService),
          authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        ],
        child: _createTestLoginApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Log In with empty form
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('Login invokes existing auth controller and shows error on failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storageService),
          authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        ],
        child: _createTestLoginApp(),
      ),
    );

    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'wrong@example.com');
    await tester.enterText(textFields.last, 'wrongpass123');

    await tester.tap(find.text('Log In'));
    await tester.pump();

    // Wait for the mock delay
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('No account found for this email.'), findsOneWidget);
  });

  testWidgets('Sign Up link navigates to signup route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storageService),
          authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        ],
        child: _createTestLoginApp(),
      ),
    );

    await tester.pumpAndSettle();

    final signUpButton = find.text("Don't have an account? Sign up");
    expect(signUpButton, findsOneWidget);
    await tester.ensureVisible(signUpButton);
    await tester.tap(signUpButton);
    await tester.pumpAndSettle();

    expect(find.text('Sign Up Screen'), findsOneWidget);
  });

  testWidgets('Reduced motion mode disables repeating ticker without errors', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storageService),
            authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
          ],
          child: _createTestLoginApp(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Small screen and keyboard viewInsets do not cause RenderFlex overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storageService),
          authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        ],
        child: _createTestLoginApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Simulate keyboard opening (bottom inset = 280)
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Log In'), findsOneWidget);
  });
}
