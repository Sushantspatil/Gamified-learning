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
    apiBaseUrl: 'https://quiz-api-50046981183.development.catalystappsail.in/api/v1',
    appTitle: 'SkillVerse (Dev)',
    enableAnalytics: false,
  );

  static const Environment staging = Environment(
    type: EnvironmentType.staging,
    apiBaseUrl: 'https://quiz-api-50046981183.development.catalystappsail.in/api/v1',
    appTitle: 'SkillVerse (Staging)',
    enableAnalytics: true,
  );

  static const Environment prod = Environment(
    type: EnvironmentType.prod,
    apiBaseUrl: 'https://quiz-api-50046981183.development.catalystappsail.in/api/v1',
    appTitle: 'SkillVerse',
    enableAnalytics: true,
  );
}
