import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double ms = 12.0;
  static const double md = 16.0;
  static const double ml = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double xxxl = 48.0;
  static const double massive = 64.0;

  static const double screenPadding = md;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMs = EdgeInsets.all(ms);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingMl = EdgeInsets.all(ml);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: screenPadding,
  );
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalScreen = EdgeInsets.symmetric(
    horizontal: screenPadding,
  );
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
}
