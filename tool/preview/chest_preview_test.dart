// A developer tool, not part of the app's test suite: renders the Chest Box
// screens to PNG files so the design can be looked at without a phone.
//
//   flutter test tool/preview/chest_preview_test.dart \
//     --dart-define=FONT_DIR=<folder with PlusJakartaSans-*.ttf> \
//     --dart-define=OUT_DIR=<folder to write the PNG files to> \
//     --dart-define=ICON_FONT=<path to materialicons-regular.otf>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/chests/presentation/chest_style.dart';
import 'package:skillverse_app/features/chests/presentation/screens/chest_screen.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';

const _fontDir = String.fromEnvironment('FONT_DIR');
const _outDir = String.fromEnvironment('OUT_DIR');
const _iconFont = String.fromEnvironment('ICON_FONT');

Future<void> _loadFonts() async {
  if (_iconFont.isNotEmpty) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(File(_iconFont).readAsBytesSync())),
      );
    await icons.load();
  }
  if (_fontDir.isEmpty) return;
  const files = {
    'regular': 'Regular',
    '500': 'Medium',
    '600': 'SemiBold',
    '700': 'Bold',
    '800': 'ExtraBold',
  };
  for (final entry in files.entries) {
    final loader = FontLoader('PlusJakartaSans_${entry.key}');
    final bytes = File(
      '$_fontDir/PlusJakartaSans-${entry.value}.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

final _shot = GlobalKey();

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  int games = 0,
  bool dark = true,
}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  final rewards = container.read(rewardsProvider.notifier);
  for (var i = 0; i < games; i++) {
    rewards.recordQuizCompleted('g$i');
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: _shot,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: const ChestScreen(),
        ),
      ),
    ),
  );
  // The chest artwork decodes off the main isolate: wait for it.
  await tester.runAsync(() async {
    final context = tester.element(find.byType(ChestScreen));
    for (final style in ChestStyle.values) {
      for (final frame in ChestFrame.values) {
        await precacheImage(AssetImage(style.frameAsset(frame)), context);
      }
    }
  });
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return container;
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary =
      tester.renderObject(find.byKey(_shot)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final dir = Directory(_outDir.isEmpty ? 'build/preview' : _outDir)
    ..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  testWidgets('hub: a new player', (tester) async {
    await _pump(tester);
    await _save(tester, 'c1_hub_new');
  });

  testWidgets('hub: two games in, none ready yet', (tester) async {
    await _pump(tester, games: 2);
    await _save(tester, 'c2_hub_progress');
  });

  testWidgets('hub: a chest is ready', (tester) async {
    await _pump(tester, games: 3);
    await _save(tester, 'c3_hub_ready');
  });

  testWidgets('hub: everything ready, light theme', (tester) async {
    await _pump(tester, games: 10, dark: false);
    await _save(tester, 'c4_hub_all_ready_light');
  });

  testWidgets('locked sheet', (tester) async {
    await _pump(tester, games: 2);
    await tester.tap(find.byKey(const Key('chest-golden')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, 'c5_locked_sheet');
  });

  testWidgets('opening: coins flying to the balance', (tester) async {
    await _pump(tester, games: 3);
    await tester.tap(find.byKey(const Key('chest-golden')));
    // The chest opens for 2.6s; the reward appears, then the coins take off.
    for (var i = 0; i < 62; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, 'c7_open_flying');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('opening: reward shown', (tester) async {
    await _pump(tester, games: 3);
    await tester.tap(find.byKey(const Key('chest-golden')));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, 'c6_open_reward');
  });
}
