import 'package:flutter/material.dart';

class AppDimensions {
  AppDimensions._();

  static const double borderRadiusSm = 8.0;
  static const double borderRadiusMd = 16.0;
  static const double borderRadiusLg = 24.0;
  static const double borderRadiusCircular = 999.0;

  static final BorderRadius radiusSm = BorderRadius.circular(borderRadiusSm);
  static final BorderRadius radiusMd = BorderRadius.circular(borderRadiusMd);
  static final BorderRadius radiusLg = BorderRadius.circular(borderRadiusLg);

  static const double buttonHeight = 54.0;
  static const double inputFieldHeight = 56.0;
  static const double avatarSizeMd = 48.0;
  static const double avatarSizeLg = 80.0;
}
