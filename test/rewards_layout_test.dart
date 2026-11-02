import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/chests/presentation/screens/chest_screen.dart';
import 'package:skillverse_app/features/shop/presentation/screens/shop_screen.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/screens/spin_wheel_screen.dart';

void main() {
  final screens = <String, Widget>{
    'spin': const SpinWheelScreen(),
    'shop': const ShopScreen(),
    'chest': const ChestScreen(),
  };
  const sizes = [
    Size(320, 568),
    Size(360, 640),
    Size(412, 915),
    Size(915, 412),
  ];

  for (final entry in screens.entries) {
    for (final size in sizes) {
      for (final dark in [false, true]) {
        for (final textScale in [1.0, 1.6]) {
          testWidgets('${entry.key} has no overflow at ${size.width.toInt()}x'
              '${size.height.toInt()} ${dark ? 'dark' : 'light'} x$textScale', (
            tester,
          ) async {
            SharedPreferences.setMockInitialValues({});
            final storage = await LocalStorageService.create();
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  localStorageServiceProvider.overrideWithValue(storage),
                  audioBackendProvider.overrideWithValue(FakeAudioBackend()),
                ],
                child: MaterialApp(
                  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
                  home: entry.value,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
