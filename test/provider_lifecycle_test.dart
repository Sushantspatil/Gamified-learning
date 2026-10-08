import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/network/network_providers.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/sudden_death_providers.dart';

class _FakeLocalStorage implements LocalStorageService {
  @override
  String? getString(String key) => 'test-token';
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  int? getInt(String key) => null;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  bool? getBool(String key) => null;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  Future<bool> remove(String key) async => true;
}

void main() {
  test('Test whether suddenDeathDatasourceProvider survives without watch', () async {
    final storage = _FakeLocalStorage();
    final config = const ApiConfig(baseUrl: 'http://localhost:8080/api/v1');
    final apiClient = ApiClient(config: config, storage: storage);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        apiConfigProvider.overrideWithValue(config),
        apiClientProvider.overrideWithValue(apiClient),
      ],
    );

    final ds1 = container.read(suddenDeathDatasourceProvider);
    await Future.delayed(const Duration(milliseconds: 50));
    final ds2 = container.read(suddenDeathDatasourceProvider);
    expect(identical(ds1, ds2), isTrue, reason: 'autoDispose provider was recreated because no one watched it!');
    container.dispose();
  });
}
