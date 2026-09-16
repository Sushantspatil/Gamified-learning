import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('refreshes an expired access token and retries the request', () async {
    final storage = await LocalStorageService.create();
    await storage.setString(StorageKeys.authToken, 'expired-token');
    await storage.setString(StorageKeys.refreshToken, 'refresh-token');
    var profileCalls = 0;

    final client = ApiClient(
      config: ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
      storage: storage,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'accessToken': 'fresh-token'},
            }),
            200,
          );
        }

        profileCalls++;
        if (profileCalls == 1) {
          expect(request.headers['Authorization'], 'Bearer expired-token');
          return http.Response(jsonEncode({'message': 'expired'}), 401);
        }
        expect(request.headers['Authorization'], 'Bearer fresh-token');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'coins': 250},
          }),
          200,
        );
      }),
    );

    final data = await client.get('/profile') as Map<String, dynamic>;

    expect(data['coins'], 250);
    expect(profileCalls, 2);
    expect(storage.getString(StorageKeys.authToken), 'fresh-token');
  });

  test('clears the saved session when refresh is rejected', () async {
    final storage = await LocalStorageService.create();
    await storage.setString(StorageKeys.currentUserId, '1');
    await storage.setString(StorageKeys.authToken, 'expired-token');
    await storage.setString(StorageKeys.refreshToken, 'invalid-refresh');

    final client = ApiClient(
      config: ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
      storage: storage,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(jsonEncode({'message': 'invalid refresh'}), 401);
        }
        return http.Response(jsonEncode({'message': 'expired'}), 401);
      }),
    );

    await expectLater(client.get('/profile'), throwsA(isA<AuthException>()));
    expect(storage.getString(StorageKeys.currentUserId), isNull);
    expect(storage.getString(StorageKeys.authToken), isNull);
    expect(storage.getString(StorageKeys.refreshToken), isNull);
  });
}
