import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asset locations and preloading for the host character.
class CharacterAssets {
  CharacterAssets._();

  /// Transparent PNG, 765x1024. Never recolored or redrawn by the app.
  static const String main = 'assets/character/character.png';
  static const double aspectRatio = 765 / 1024;

  static const String layersDir = 'assets/character/layers/';
  static const String head = '${layersDir}head.png';
  static const String eyesOpen = '${layersDir}eyes_open.png';
  static const String eyesClosed = '${layersDir}eyes_closed.png';
  static const String mouthClosed = '${layersDir}mouth_closed.png';
  static const String mouthOpen = '${layersDir}mouth_open.png';
  static const String armRight = '${layersDir}arm_right.png';
  static const String body = '${layersDir}body.png';

  static const List<String> layerFiles = [
    body,
    armRight,
    head,
    eyesOpen,
    eyesClosed,
    mouthClosed,
    mouthOpen,
  ];

  /// True only when every optional layer is bundled (declared in pubspec).
  /// Any failure means "no layers": the whole image is used instead.
  static Future<bool> layersAvailable([AssetBundle? bundle]) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(
        bundle ?? rootBundle,
      );
      final assets = manifest.listAssets().toSet();
      return layerFiles.every(assets.contains);
    } catch (_) {
      return false;
    }
  }
}

/// Decodes the character into the image cache ahead of the first question so
/// there is no pop-in. Never throws: gameplay must not depend on the art.
Future<void> precacheCharacter(BuildContext context) async {
  try {
    await precacheImage(const AssetImage(CharacterAssets.main), context);
  } catch (_) {
    // Missing or corrupt asset: the view hides itself instead.
  }
}
