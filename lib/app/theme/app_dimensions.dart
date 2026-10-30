import 'package:flutter/material.dart';

class AppDimensions {
  AppDimensions._();

  static const double borderRadiusSm = 14.0;
  static const double borderRadiusMd = 18.0;
  static const double borderRadiusLg = 24.0;
  static const double borderRadiusCard = 24.0;
  static const double borderRadiusCircular = 999.0;

  static final BorderRadius radiusSm = BorderRadius.circular(borderRadiusSm);
  static final BorderRadius radiusMd = BorderRadius.circular(borderRadiusMd);
  static final BorderRadius radiusLg = BorderRadius.circular(borderRadiusLg);
  static final BorderRadius radiusCard = BorderRadius.circular(
    borderRadiusCard,
  );
  static final BorderRadius radiusCircular = BorderRadius.circular(
    borderRadiusCircular,
  );

  static const double buttonHeight = 54.0;
  static const double inputFieldHeight = 56.0;
  static const double avatarSizeSm = 36.0;
  static const double avatarSizeMd = 48.0;
  static const double avatarSizeLg = 80.0;

  /// Border width for chunky, game-style outlines.
  static const double borderWidth = 2.0;

  /// Height of the solid "3D" edge under raised buttons and cards.
  static const double raisedDepth = 5.0;
  static const double cardDepth = 4.0;
}
