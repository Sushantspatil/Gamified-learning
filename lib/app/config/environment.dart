/// Defines environment modes for the app (Development, Staging, Production)
enum EnvironmentType { dev, staging, prod }

class Environment {
  final EnvironmentType type;
  final String apiBaseUrl;
  final String appTitle;
  final bool enableAnalytics;

  const Environment({
    required this.type,
    required this.apiBaseUrl,
    required this.appTitle,
    this.enableAnalytics = true,
  });

  static const Environment dev = Environment(
    type: EnvironmentType.dev,
    apiBaseUrl: 'https://dev-api.skillverse.app',
    appTitle: 'SkillVerse (Dev)',
    enableAnalytics: false,
  );

  static const Environment staging = Environment(
    type: EnvironmentType.staging,
    apiBaseUrl: 'https://staging-api.skillverse.app',
    appTitle: 'SkillVerse (Staging)',
    enableAnalytics: true,
  );

  static const Environment prod = Environment(
    type: EnvironmentType.prod,
    apiBaseUrl: 'https://api.skillverse.app',
    appTitle: 'SkillVerse',
    enableAnalytics: true,
  );
}
