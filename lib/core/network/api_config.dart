import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

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
  /// - Android Emulator: http://10.0.2.2:8080/api/v1
  /// - iOS Simulator / macOS / Web / Linux / Windows: http://localhost:8080/api/v1
  factory ApiConfig.defaultConfig({String? customBaseUrl}) {
    if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
      return ApiConfig(baseUrl: customBaseUrl);
    String url = customBaseUrl?.trim() ?? '';
    if (url.isEmpty) {
      url = const String.fromEnvironment('BASE_URL').trim();
    }

    const envBaseUrl = String.fromEnvironment('BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return ApiConfig(baseUrl: envBaseUrl);
    if (url.isEmpty) {
      final host = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2:8080' : 'localhost:8080';
      return ApiConfig(baseUrl: 'http://$host/api/v1');
    }

    return const ApiConfig(
      baseUrl:
          'localhost:8080',
    );
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    if (!url.endsWith('/api/v1')) {
      url = url.endsWith('/') ? '${url}api/v1' : '$url/api/v1';
    }

    return ApiConfig(baseUrl: url);
  }
}
