import 'dart:async';
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

  test('can call backend root routes outside the api v1 prefix', () async {
    final storage = await LocalStorageService.create();

    final client = ApiClient(
      config: ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
      storage: storage,
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'https://api.example.com/profile');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'name': 'Sushant Patil'},
          }),
          200,
        );
      }),
    );

    final data =
        await client.get('/profile', useApiRoot: true) as Map<String, dynamic>;

    expect(data['name'], 'Sushant Patil');
  });

  group('refresh race', () {
    Future<
      (LocalStorageService, Completer<http.Response>, ApiClient, List<String>)
    >
    setUpRace() async {
      final storage = await LocalStorageService.create();
      await storage.setString(StorageKeys.currentUserId, 'A');
      await storage.setString(StorageKeys.authToken, 'A1');
      await storage.setString(StorageKeys.refreshToken, 'RA');
      final refresh = Completer<http.Response>();
      final seen = <String>[];
      final client = ApiClient(
        config: ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            seen.add('refresh');
            return refresh.future;
          }
          seen.add(request.headers['Authorization'] ?? '');
          if (request.headers['Authorization'] == 'Bearer A1') {
            return http.Response(jsonEncode({'message': 'expired'}), 401);
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );
      return (storage, refresh, client, seen);
    }

    http.Response refreshed(String token) => http.Response(
      jsonEncode({
        'success': true,
        'data': {'accessToken': token},
      }),
      200,
    );

    test(
      'a refresh that finishes after logout does not bring the token back',
      () async {
        final (storage, refresh, client, _) = await setUpRace();
        final call = client.get('/profile');
        await Future<void>.delayed(Duration.zero);
        // Logout completes while the refresh is still in flight.
        await storage.remove(StorageKeys.currentUserId);
        await storage.remove(StorageKeys.authToken);
        await storage.remove(StorageKeys.refreshToken);
        refresh.complete(refreshed('A2'));

        await expectLater(call, throwsA(isA<AuthException>()));
        expect(storage.getString(StorageKeys.authToken), isNull);
      },
    );

    test("a stale refresh never overwrites the next account's token", () async {
      final (storage, refresh, client, seen) = await setUpRace();
      final call = client.get('/profile');
      await Future<void>.delayed(Duration.zero);
      // Account B signs in on the same device meanwhile.
      await storage.setString(StorageKeys.currentUserId, 'B');
      await storage.setString(StorageKeys.authToken, 'B1');
      await storage.setString(StorageKeys.refreshToken, 'RB');
      refresh.complete(refreshed('A2'));

      await expectLater(call, throwsA(isA<AuthException>()));
      expect(storage.getString(StorageKeys.authToken), 'B1');
      expect(storage.getString(StorageKeys.refreshToken), 'RB');
      expect(seen, isNot(contains('Bearer A2'))); // A's request not retried
    });

    test('a failed stale refresh does not sign the next account out', () async {
      final (storage, refresh, client, _) = await setUpRace();
      final call = client.get('/profile');
      await Future<void>.delayed(Duration.zero);
      await storage.setString(StorageKeys.currentUserId, 'B');
      await storage.setString(StorageKeys.authToken, 'B1');
      await storage.setString(StorageKeys.refreshToken, 'RB');
      refresh.complete(http.Response(jsonEncode({'message': 'revoked'}), 401));

      await expectLater(call, throwsA(isA<AuthException>()));
      expect(storage.getString(StorageKeys.currentUserId), 'B');
      expect(storage.getString(StorageKeys.authToken), 'B1');
    });

    test(
      'concurrent 401s share one refresh and keep a rotated token',
      () async {
        final (storage, refresh, client, seen) = await setUpRace();
        final first = client.get('/profile');
        final second = client.get('/wallet');
        await Future<void>.delayed(Duration.zero);
        refresh.complete(
          http.Response(
            jsonEncode({
              'success': true,
              'data': {'accessToken': 'A2', 'refreshToken': 'RA2'},
            }),
            200,
          ),
        );
        await Future.wait([first, second]);

        expect(seen.where((s) => s == 'refresh'), hasLength(1));
        expect(storage.getString(StorageKeys.authToken), 'A2');
        expect(storage.getString(StorageKeys.refreshToken), 'RA2');
      },
    );
  });

  test('only real local hosts are treated as local (http)', () {
    expect(ApiConfig.isLocalUrl('http://localhost:8080/api/v1'), isTrue);
    expect(ApiConfig.isLocalUrl('10.0.2.2:8080/api/v1'), isTrue);
    expect(ApiConfig.isLocalUrl('https://127.0.0.1/api'), isTrue);
    expect(ApiConfig.isLocalUrl('https://localhost.example.com/api'), isFalse);
    expect(ApiConfig.isLocalUrl('https://api.example.com/localhost'), isFalse);
    expect(
      ApiConfig.defaultConfig(
        customBaseUrl: 'localhost.example.com/api/v1',
      ).baseUrl,
      startsWith('https://'),
    );
  });
}
