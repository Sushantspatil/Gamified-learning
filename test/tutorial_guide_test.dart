import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/onboarding/presentation/screens/how_to_play_tutorial_screen.dart';

void main() {
  for (final size in const [Size(320, 568), Size(412, 915)]) {
    testWidgets(
      'tutorial works without 3D and gives the space back (${size.width.toInt()}x${size.height.toInt()})',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = await LocalStorageService.create();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [localStorageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const HowToPlayTutorialScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No WebView here: the guide's space is returned to the slides.
        expect(find.byKey(const Key('tutorial_guide')), findsNothing);
        expect(find.text('Learn at Your Pace'), findsOneWidget);

        // Swiping still works and nothing throws or overflows.
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Play & Practice'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
