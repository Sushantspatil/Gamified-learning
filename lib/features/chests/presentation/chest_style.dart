import 'package:flutter/material.dart';

/// The four artwork stages of every chest, in playing order.
enum ChestFrame { closed, opening, burst, opened }

/// The three chest designs. Each has its own artwork (one transparent PNG per
/// [ChestFrame] under `assets/chests/<id>/`) and its own light and particle
/// colours.
enum ChestStyle {
  galaxy(
    title: 'Galaxy Chest',
    // Size of the cropped artwork, so it is never stretched.
    artWidth: 249,
    artHeight: 261,
    colors: [Color(0xFFB57BFF), Color(0xFF6C86FF), Color(0xFFFF8BDD)],
  ),
  golden(
    title: 'Golden Chest',
    artWidth: 252,
    artHeight: 246,
    colors: [Color(0xFFFFD34A), Color(0xFFFF9A1F), Color(0xFFFFF3B0)],
  ),
  cyber(
    title: 'Cyber Chest',
    artWidth: 258,
    artHeight: 258,
    colors: [Color(0xFF22E6FF), Color(0xFF3D7BFF), Color(0xFF8CFFF2)],
  );

  final String title;
  final double artWidth;
  final double artHeight;

  /// Light and particle colours: primary, secondary, highlight.
  final List<Color> colors;

  const ChestStyle({
    required this.title,
    required this.artWidth,
    required this.artHeight,
    required this.colors,
  });

  double get aspectRatio => artWidth / artHeight;

  String frameAsset(ChestFrame frame) =>
      'assets/chests/$name/${frame.name}.png';

  Color get primary => colors[0];
  Color get secondary => colors[1];
  Color get highlight => colors[2];
}
