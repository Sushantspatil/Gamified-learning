import 'package:flutter/material.dart';

class AppDimensions {
  AppDimensions._();

  static const double borderRadiusSm = 12.0;
  static const double borderRadiusMd = 16.0;
  static const double borderRadiusLg = 20.0;
  static const double borderRadiusCard = 22.0;
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

  static const double buttonHeight = 52.0;
  static const double inputFieldHeight = 54.0;
  static const double avatarSizeSm = 36.0;
  static const double avatarSizeMd = 48.0;
  static const double avatarSizeLg = 80.0;
}
