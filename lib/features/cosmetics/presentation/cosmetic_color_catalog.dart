import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Maps a CosmeticItem.colorKey to its concrete display color, mirroring
/// the AvatarCatalog pattern in the profile feature.
class CosmeticColorCatalog {
  CosmeticColorCatalog._();

  static const Map<String, Color> colors = {
    'gold': AppColors.coinGold,
    'cyan': AppColors.gemCyan,
    'fire': AppColors.streakFire,
    'royal': AppColors.primary,
  };

  static Color? colorFor(String? colorKey) => colors[colorKey];
}
