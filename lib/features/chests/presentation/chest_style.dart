import 'package:flutter/material.dart';

import '../../rewards/domain/rewards_models.dart';

/// The four artwork stages of every chest, in playing order.
enum ChestFrame { closed, opening, burst, opened }

/// The three chest designs. Each has its own artwork (one transparent PNG per
/// [ChestFrame] under `assets/chests/<id>/`) and its own light and particle
/// colours.
enum ChestStyle {
  // Same order as [ChestTier]: the order they are earned in.
  golden(
    title: 'Golden Chest',
    prize: 'Coins',
    // Size of the cropped artwork, so it is never stretched.
    artWidth: 252,
    artHeight: 246,
    colors: [Color(0xFFFFD34A), Color(0xFFFF9A1F), Color(0xFFFFF3B0)],
  ),
  cyber(
    title: 'Cyber Chest',
    prize: 'Cosmetics',
    artWidth: 258,
    artHeight: 258,
    colors: [Color(0xFF22E6FF), Color(0xFF3D7BFF), Color(0xFF8CFFF2)],
  ),
  galaxy(
    title: 'Galaxy Chest',
    prize: 'Gems',
    artWidth: 249,
    artHeight: 261,
    colors: [Color(0xFFB57BFF), Color(0xFF6C86FF), Color(0xFFFF8BDD)],
  );

  final String title;

  /// What this chest pays, for a short label.
  final String prize;
  final double artWidth;
  final double artHeight;

  /// Light and particle colours: primary, secondary, highlight.
  final List<Color> colors;

  const ChestStyle({
    required this.title,
    required this.prize,
    required this.artWidth,
    required this.artHeight,
    required this.colors,
  });

  ChestTier get tier => ChestTier.values.byName(name);

  static ChestStyle of(ChestTier tier) => values.byName(tier.name);

  double get aspectRatio => artWidth / artHeight;

  String frameAsset(ChestFrame frame) =>
      'assets/chests/$name/${frame.name}.png';

  Color get primary => colors[0];
  Color get secondary => colors[1];
  Color get highlight => colors[2];
}
