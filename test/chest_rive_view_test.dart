import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/chests/presentation/chest_style.dart';
import 'package:skillverse_app/features/chests/presentation/widgets/chest_effects_painter.dart';
import 'package:skillverse_app/features/chests/presentation/widgets/chest_rive_view.dart';

/// A bundle whose asset list says the golden chest has a Rive file, whose
/// bytes are [riv] (not a real Rive file in these tests).
class _Bundle extends CachingAssetBundle {
  final ByteData riv;
  final bool listRive;
  _Bundle({required this.riv, this.listRive = true});

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final path = chestRiveAsset(ChestStyle.golden);
      return const StandardMessageCodec().encodeMessage(<String, Object>{
        if (listRive)
          path: [
            <String, Object>{'asset': path},
          ],
        'assets/chests/golden/closed.png': [
          <String, Object>{'asset': 'assets/chests/golden/closed.png'},
        ],
      })!;
    }
    if (key == chestRiveAsset(ChestStyle.golden)) return riv;
    throw FlutterError('missing $key');
  }
}

void main() {
  setUp(resetChestRiveCache);

  Future<void> pumpView(
    WidgetTester tester, {
    required AssetBundle bundle,
    bool reduceMotion = false,
  }) async {
    final progress = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ChestRiveView(
            style: ChestStyle.golden,
            progress: progress,
            height: 200,
            reduceMotion: reduceMotion,
            bundle: bundle,
            fallback: const SizedBox(key: Key('film'), width: 10, height: 10),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    progress.forward();
    await tester.pumpAndSettle();
  }

  testWidgets('a chest without a Rive file keeps the picture film', (
    tester,
  ) async {
    await pumpView(tester, bundle: _Bundle(riv: ByteData(0), listRive: false));
    expect(find.byKey(const Key('film')), findsOneWidget);
    expect(find.byKey(const Key('chest_rive_view')), findsNothing);
  });

  testWidgets('reduce motion keeps the picture film', (tester) async {
    await pumpView(
      tester,
      bundle: _Bundle(riv: ByteData(0)),
      reduceMotion: true,
    );
    expect(find.byKey(const Key('film')), findsOneWidget);
  });

  testWidgets('a broken Rive file falls back to the picture film', (
    tester,
  ) async {
    final junk = ByteData.sublistView(Uint8List.fromList(List.filled(64, 7)));
    await pumpView(tester, bundle: _Bundle(riv: junk));
    expect(find.byKey(const Key('film')), findsOneWidget);
    expect(find.byKey(const Key('chest_rive_view')), findsNothing);
  });

  testWidgets('the Rive chest gets the app light effects behind it', (
    tester,
  ) async {
    final progress = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ChestRiveFrame(
            style: ChestStyle.golden,
            progress: progress,
            height: 200,
            child: const SizedBox(key: Key('rive')),
          ),
        ),
      ),
    );
    progress.value = 0.5;
    await tester.pump();

    final effects = find.byKey(const Key('chest_rive_effects'));
    expect(effects, findsOneWidget);
    expect(
      tester.widget<CustomPaint>(effects).painter,
      isA<ChestEffectsPainter>(),
    );
    // The effects sit behind the chest, which is the last (top) layer.
    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(ChestRiveFrame),
        matching: find.byType(Stack),
      ),
    );
    final top = stack.children.last as Positioned;
    expect((top.child as SizedBox).key, const Key('rive'));
    expect(tester.getSize(find.byType(ChestRiveFrame)).height, 200);
    expect(tester.takeException(), isNull);
  });

  test('each chest has its own file name', () {
    expect(
      ChestStyle.values.map(chestRiveAsset).toList(),
      ChestStyle.values.map((s) => 'assets/chests/rive/${s.name}.riv').toList(),
    );
  });
}
