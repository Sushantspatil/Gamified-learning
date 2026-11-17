// A developer tool, not part of the app's test suite: renders the chest-opening
// animation to PNG files, one picture per moment, so the animation can be
// judged without a phone.
//
//   flutter test tool/preview/chest_anim_preview_test.dart \
//     --dart-define=OUT_DIR=<folder to write the PNG files to>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/chests/presentation/chest_style.dart';
import 'package:skillverse_app/features/chests/presentation/widgets/chest_open_view.dart';

const _outDir = String.fromEnvironment('OUT_DIR');

final _shot = GlobalKey();

/// The moments of the opening to look at.
const _moments = [0.0, 0.12, 0.2, 0.23, 0.32, 0.42, 0.45, 0.6, 0.7, 0.8, 1.0];

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold));
    for (final style in ChestStyle.values) {
      for (final frame in ChestFrame.values) {
        await precacheImage(AssetImage(style.frameAsset(frame)), context);
      }
    }
  });
}

Future<void> _save(WidgetTester tester, String name, double pixelRatio) async {
  final boundary =
      tester.renderObject(find.byKey(_shot)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final dir = Directory(_outDir.isEmpty ? 'build/preview' : _outDir)
    ..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
}

void main() {
  /// One row per chest, one column per moment of the opening.
  testWidgets('contact sheet: every moment of every chest', (tester) async {
    const cell = 150.0;
    tester.view.physicalSize = Size(cell * _moments.length, cell * 3);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shot,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF05060C),
            body: Column(
              children: [
                for (final style in ChestStyle.values)
                  SizedBox(
                    height: cell,
                    child: Row(
                      children: [
                        for (final t in _moments)
                          SizedBox(
                            width: cell,
                            child: Center(
                              child: ChestOpenView(
                                style: style,
                                progress: AlwaysStoppedAnimation<double>(t),
                                height: cell * 0.7,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await _save(tester, 'a1_contact_sheet', 1);
  });

  /// One chest as a phone draws it: 300 logical pixels tall on a 3x screen.
  testWidgets('one chest at full phone size (3x)', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shot,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF05060C),
            body: Center(
              child: ChestOpenView(
                style: ChestStyle.galaxy,
                progress: const AlwaysStoppedAnimation<double>(1.0),
                height: 300,
              ),
            ),
          ),
        ),
      ),
    );
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await _save(tester, 'a2_galaxy_opened_3x', 3);
  });
}
