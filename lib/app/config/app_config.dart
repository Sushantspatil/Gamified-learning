import 'package:flutter/foundation.dart';

import 'environment.dart';

/// Global application configuration holder initialized at app launch
class AppConfig {
  static late Environment _environment;

  static void initialize(Environment env) {
    _environment = env;
  }

  static Environment get environment => _environment;
  static bool get isDev => _environment.type == EnvironmentType.dev;
  static bool get isProduction => _environment.type == EnvironmentType.prod;

  /// Development previews may run in debug and profile builds, never release.
  static bool get developmentPreviewsEnabled => !kReleaseMode;
}
