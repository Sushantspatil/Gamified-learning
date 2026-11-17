import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/chests/presentation/chest_style.dart';

/// Width and height from a PNG's header.
(int, int) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(Uint8List.fromList(bytes.sublist(0, 24)));
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chest artwork', () {
    test('every frame has a sharper 2x and 3x version next to it', () {
      for (final style in ChestStyle.values) {
        for (final frame in ChestFrame.values) {
          final base = style.frameAsset(frame);
          final (w, h) = _pngSize(base);
          final dir = File(base).parent.path;
          final name = base.split('/').last;
          final (w2, h2) = _pngSize('$dir/2.0x/$name');
          final (w3, h3) = _pngSize('$dir/3.0x/$name');
          expect((w2, h2), (w * 2, h * 2), reason: '$base at 2x');
          expect((w3, h3), (w * 3, h * 3), reason: '$base at 3x');
        }
      }
    });

    test('the 1x frame keeps the size the layout is designed around', () {
      for (final style in ChestStyle.values) {
        for (final frame in ChestFrame.values) {
          final (w, h) = _pngSize(style.frameAsset(frame));
          expect(w, style.artWidth.round(), reason: '${style.name} width');
          expect(h, style.artHeight.round(), reason: '${style.name} height');
        }
      }
    });

    test(
      'Flutter knows all three versions and picks by screen density',
      () async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        for (final style in ChestStyle.values) {
          for (final frame in ChestFrame.values) {
            final asset = style.frameAsset(frame);
            final variants = manifest.getAssetVariants(asset);
            expect(variants, isNotNull, reason: asset);
            final ratios = {
              for (final v in variants!) v.key: v.targetDevicePixelRatio ?? 1.0,
            };
            expect(ratios.length, 3, reason: '$asset variants: $ratios');
            expect(ratios.values.toSet(), {1.0, 2.0, 3.0}, reason: asset);
            expect(
              ratios.keys.any((k) => k.contains('/3.0x/')),
              isTrue,
              reason: asset,
            );
          }
        }
      },
    );
  });
}
