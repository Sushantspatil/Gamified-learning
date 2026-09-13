import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'api_client.dart';
import 'api_config.dart';

final apiConfigProvider = Provider<ApiConfig>((ref) {
  return ApiConfig.defaultConfig();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(apiConfigProvider);
  final storage = ref.watch(localStorageServiceProvider);
  final client = ApiClient(config: config, storage: storage);
  ref.onDispose(client.close);
  return client;
});
