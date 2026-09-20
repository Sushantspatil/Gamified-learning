class ApiConfig {
  static const String defaultProductionBaseUrl =
      'https://gamifiedquizappdigitalhq-production.up.railway.app/api/v1';

  final String baseUrl;
  final Duration timeout;

  const ApiConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
  });

  /// Check whether the URL refers to a local development host.
  static bool isLocalUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2');
  }

  /// The root host URL without the /api/v1 suffix.
  /// Uses http:// for local hosts and https:// for production hosts.
  String get rootUrl {
    var url = baseUrl;
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - 7);
    }
    if (isLocalUrl(url)) {
      if (url.startsWith('https://')) {
        url = 'http://${url.substring(8)}';
      } else if (!url.startsWith('http://')) {
        url = 'http://$url';
      }
    } else {
      if (url.startsWith('http://')) {
        url = 'https://${url.substring(7)}';
      } else if (!url.startsWith('https://')) {
        url = 'https://$url';
      }
    }
    return url;
  }

  /// WebSocket root URL (ws:// for local hosts, wss:// for production hosts).
  String get wsRootUrl {
    final root = rootUrl;
    if (root.startsWith('http://')) {
      return 'ws://${root.substring(7)}';
    } else if (root.startsWith('https://')) {
      return 'wss://${root.substring(8)}';
    }
    return isLocalUrl(root) ? 'ws://$root' : 'wss://$root';
  }

  /// Dedicated WebSocket endpoint for game/multiplayer.
  String get gameWsUrl => '$wsRootUrl/ws/game';

  /// Factory that resolves the API base URL.
  /// Automatically retains http:// and ws:// for localhost/local development
  /// and strictly enforces https:// and wss:// for production/remote domains.
  factory ApiConfig.defaultConfig({String? customBaseUrl}) {
    String url = customBaseUrl?.trim() ?? '';
    if (url.isEmpty) {
      url = const String.fromEnvironment('BASE_URL').trim();
    }

    if (url.isEmpty) {
      return const ApiConfig(baseUrl: defaultProductionBaseUrl);
    }

    final isLocal = isLocalUrl(url);

    if (isLocal) {
      if (url.startsWith('https://')) {
        url = 'http://${url.substring(8)}';
      } else if (url.startsWith('wss://')) {
        url = 'http://${url.substring(6)}';
      } else if (url.startsWith('ws://')) {
        url = 'http://${url.substring(5)}';
      } else if (!url.startsWith('http://')) {
        url = 'http://$url';
      }
    } else {
      if (url.startsWith('http://')) {
        url = 'https://${url.substring(7)}';
      } else if (url.startsWith('ws://')) {
        url = 'https://${url.substring(5)}';
      } else if (url.startsWith('wss://')) {
        url = 'https://${url.substring(6)}';
      } else if (!url.startsWith('https://')) {
        url = 'https://$url';
      }
    }

    // Ensure it ends with /api/v1
    if (!url.endsWith('/api/v1')) {
      url = url.endsWith('/') ? '${url}api/v1' : '$url/api/v1';
    }

    return ApiConfig(baseUrl: url);
  }
}

