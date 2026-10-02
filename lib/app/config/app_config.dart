import 'package:flutter/foundation.dart';

import 'environment.dart';

/// Global application configuration holder initialized at app launch
class AppConfig {
  static Environment _environment = Environment.dev;

  static bool? _developmentPreviewsOverride;

  /// Explicit build-time flag (--dart-define=ENABLE_SUDDEN_DEATH_MOCK=true)
  /// allowing testers to install and test release APK builds on physical devices
  /// while keeping regular production builds backend-dependent and mock-free.
  static const bool enableSuddenDeathMock =
      bool.fromEnvironment('ENABLE_SUDDEN_DEATH_MOCK', defaultValue: false);

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

  /// Development previews run in:
  /// 1. Builds with explicit --dart-define=ENABLE_SUDDEN_DEATH_MOCK=true (test/QA APK builds)
  /// 2. Local debug/development runs (!kReleaseMode && !isProduction)
  /// 3. In automated tests where _developmentPreviewsOverride is set
  /// Standard production release builds (without the flag) always evaluate to false.
  static bool get developmentPreviewsEnabled =>
      _developmentPreviewsOverride ??
      (enableSuddenDeathMock || (!kReleaseMode && !isProduction));
}
