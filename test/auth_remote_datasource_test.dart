import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/authentication/data/datasources/remote/auth_remote_datasource.dart';

void main() {
  test(
    'signup verifies email before creating and logging in the user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final requests = <http.Request>[];
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'https://example.test/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'access-token',
                  'refreshToken': 'refresh-token',
                  'client': {
                    'id': 42,
                    'email': 'ada@example.com',
                    'username': 'Ada',
                  },
                },
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'data': <String, dynamic>{}}), 200);
        }),
      );
      final datasource = AuthRemoteDatasource(
        apiClient: client,
        storage: storage,
      );

      await datasource.requestSignUpOtp(email: ' ada@example.com ');
      await datasource.verifySignUpOtp(
        email: ' ada@example.com ',
        otp: ' 123456 ',
      );
      final user = await datasource.signUp(
        email: ' ada@example.com ',
        password: 'password123',
        displayName: ' Ada ',
      );

      expect(requests.map((request) => request.url.path), [
        '/api/v1/auth/register/email-request',
        '/api/v1/auth/register/email-verify',
        '/api/v1/auth/register/validate-basic',
        '/api/v1/auth/login',
      ]);
      expect(jsonDecode(requests[0].body), {'email': 'ada@example.com'});
      expect(jsonDecode(requests[1].body), {
        'email': 'ada@example.com',
        'otp': '123456',
      });
      expect(user.id, '42');
      expect(storage.getString(StorageKeys.authToken), 'access-token');
      expect(storage.getString(StorageKeys.refreshToken), 'refresh-token');

      client.close();
    },
  );
}
