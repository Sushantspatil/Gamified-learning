import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/profile/data/datasources/mock/profile_mock_datasource.dart';
import 'package:skillverse_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:skillverse_app/features/profile/presentation/screens/edit_profile_screen.dart';

/// Two users exist: "Test User" (signed in) and "Taken Name" (someone else).
Future<ProviderContainer> _signedIn() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  final auth = AuthMockDatasource();
  await auth.signUp(
    email: 'other@example.com',
    password: 'password123',
    displayName: 'Taken Name',
  );
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      authDatasourceProvider.overrideWithValue(auth),
      profileDatasourceProvider.overrideWithValue(ProfileMockDatasource()),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(authControllerProvider.notifier)
      .login(email: 'test@example.com', password: 'password123');
  return container;
}

String? _name(ProviderContainer c) =>
    c.read(authControllerProvider).valueOrNull?.displayName;

void main() {
  group('AuthController.updateDisplayName', () {
    test('a free name is saved', () async {
      final c = await _signedIn();
      await c.read(authControllerProvider.notifier).updateDisplayName('Fresh');
      expect(_name(c), 'Fresh');
    });

    test(
      'a taken name is rejected (any case) and the user stays signed in',
      () async {
        final c = await _signedIn();
        await expectLater(
          c
              .read(authControllerProvider.notifier)
              .updateDisplayName('  taken NAME '),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              'That display name is already taken.',
            ),
          ),
        );
        // Not logged out, name unchanged.
        expect(_name(c), 'Test User');
        expect(c.read(authControllerProvider).hasError, isFalse);
      },
    );

    test('keeping your own name is not "taken"', () async {
      final c = await _signedIn();
      await c
          .read(authControllerProvider.notifier)
          .updateDisplayName('test user');
      expect(_name(c), 'test user');
    });
  });

  group('Edit Profile screen', () {
    Future<void> open(WidgetTester tester, ProviderContainer c) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('taken name: shows the reason, stays open, keeps the old name', (
      tester,
    ) async {
      // Real async for the mock datasource latency; the rest runs on fake time.
      final c = (await tester.runAsync(_signedIn))!;
      await open(tester, c);

      await tester.enterText(find.byType(TextFormField).first, 'Taken Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('That display name is already taken.'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget); // still open
      expect(_name(c), 'Test User');

      // Typing again clears the message; a free name then saves and closes.
      await tester.enterText(find.byType(TextFormField).first, 'Brand New');
      await tester.pump();
      expect(find.text('That display name is already taken.'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsNothing);
      expect(_name(c), 'Brand New');
    });
  });
}
