import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 280);
  static const Duration celebration = Duration(milliseconds: 700);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve snappy = Curves.easeOutCubic;

  /// Returns true when the system or user has explicitly requested animations
  /// to be disabled or reduced (e.g. Android "Remove animations" setting).
  ///
  /// Accessible navigation (TalkBack, screen readers) is NOT treated as
  /// disabling animations.
  static bool reduceMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations ?? false;
  }

  /// Whether an assistive technology service (such as TalkBack or screen reader)
  /// is active. This can be used for timeouts or screen reader announcements,
  /// but must NOT suppress visual animations globally.
  static bool accessibleNavigation(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.accessibleNavigation ?? false;
  }

  static Duration duration(BuildContext context, Duration duration) {
    return reduceMotion(context) ? Duration.zero : duration;
  }
}
