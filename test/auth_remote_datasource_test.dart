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
    'signup uses exact backend routes /auth/signup/send-code and /auth/signup/verify',
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
          if (path.endsWith('/auth/signup/send-code')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'email': 'ada@example.com',
                  'cooldownSeconds': 60,
                  'expiresIn': 600,
                  'message': 'Verification code sent',
                },
              }),
              200,
            );
          }
          if (path.endsWith('/auth/signup/verify')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'access-token',
                  'refreshToken': 'refresh-token',
                  'tokenType': 'Bearer',
                  'expiresIn': 2592000,
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

      await datasource.requestSignUpOtp(
        email: ' ada@example.com ',
        password: 'password123',
        displayName: ' Ada ',
      );
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
        '/api/v1/auth/signup/send-code',
        '/api/v1/auth/signup/verify',
      ]);
      expect(jsonDecode(requests[0].body), {
        'email': 'ada@example.com',
        'password': 'password123',
        'displayName': 'Ada',
      });
      expect(jsonDecode(requests[1].body), {
        'email': 'ada@example.com',
        'code': '123456',
      });
      expect(user.id, '42');
      expect(user.displayName, 'Ada');
      expect(storage.getString(StorageKeys.authToken), 'access-token');
      expect(storage.getString(StorageKeys.refreshToken), 'refresh-token');

      client.close();
    },
  );
}
