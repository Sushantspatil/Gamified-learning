import 'package:flutter/foundation.dart';

import 'environment.dart';

/// Global application configuration holder initialized at app launch
class AppConfig {
  static Environment _environment = Environment.dev;

  static bool? _developmentPreviewsOverride;

  static void initialize(Environment env) {
    _environment = env;
  }

  static Environment get environment => _environment;
  static bool get isDev => _environment.type == EnvironmentType.dev;
  static bool get isProduction => _environment.type == EnvironmentType.prod;

  @visibleForTesting
  static set developmentPreviewsOverride(bool? value) {
    _developmentPreviewsOverride = value;
  }

  /// Development previews may run in dev/debug builds, never release or production.
  static bool get developmentPreviewsEnabled =>
      _developmentPreviewsOverride ?? (!kReleaseMode && !isProduction);
}
