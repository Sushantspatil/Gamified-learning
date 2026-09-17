class ApiConfig {
  final String baseUrl;
  final Duration timeout;

  const ApiConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 10),
  });

  /// Factory that automatically resolves host based on target platform:
  /// - Android Emulator: 10.0.2.2:8080
  /// - iOS Simulator / macOS / Web / Linux / Windows: localhost:8080
  factory ApiConfig.defaultConfig({String? customBaseUrl}) {
    if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
      return ApiConfig(baseUrl: customBaseUrl);
    }

    const envBaseUrl = String.fromEnvironment('BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return ApiConfig(baseUrl: envBaseUrl);
    }

    return const ApiConfig(
      baseUrl:
          'https://gamifiedquizappdigitalhq-production.up.railway.app/api/v1',
    );
  }
}
