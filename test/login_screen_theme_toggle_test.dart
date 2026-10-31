import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/app/theme/theme_mode_controller.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:skillverse_app/shared/widgets/theme_mode_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoginScreen renders ThemeModeMenu and toggles dark/light theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final pref = ref.watch(themeModeControllerProvider);
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: pref.themeMode,
              home: const LoginScreen(),
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Verify ThemeModeMenu is present
    expect(find.byType(ThemeModeMenu), findsOneWidget);

    // Initial preference is dark by default
    final element = tester.element(find.byType(LoginScreen));
    final container = ProviderScope.containerOf(element);
    expect(container.read(themeModeControllerProvider), AppThemePreference.dark);

    // Tap theme toggle button
    await tester.tap(find.byType(ThemeModeMenu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify preference switched to light
    expect(container.read(themeModeControllerProvider), AppThemePreference.light);

    // Tap again to switch back to dark
    await tester.tap(find.byType(ThemeModeMenu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(themeModeControllerProvider), AppThemePreference.dark);
  });
}
