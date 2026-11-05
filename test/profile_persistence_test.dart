import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/profile/data/datasources/remote/profile_remote_datasource.dart';

class _Storage implements LocalStorageService {
  final Map<String, String> map = {};

  @override
  String? getString(String key) => map[key];

  @override
  Future<bool> setString(String key, String value) async {
    map[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => null;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> remove(String key) async {
    map.remove(key);
    return true;
  }
}

/// A set-up account must stay set up: whatever the network does at launch, the
/// player is not sent back through Profile Setup.
void main() {
  late _Storage storage;
  late bool offline;
  late Map<String, dynamic> profileBody;

  ProfileRemoteDatasource make() {
    final client = MockClient((request) async {
      if (offline) throw const SocketException('no network');
      return http.Response(
        jsonEncode({'success': true, 'data': profileBody}),
        200,
      );
    });
    return ProfileRemoteDatasource(
      apiClient: ApiClient(
        config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
        storage: storage,
        httpClient: client,
      ),
      storage: storage,
    );
  }

  setUp(() {
    storage = _Storage();
    offline = false;
    profileBody = {
      'uuid': 'u1',
      'name': 'Ada',
      'email': 'ada@example.com',
      'avatarId': 'avatar-2',
      'class': '11th',
      'board': 'Maharashtra State Board',
      'isOnboarded': false,
      'level': 9,
    };
  });

  test('the server having a class and board counts as set up', () async {
    final profile = await make().getProfile('u1');
    expect(profile.profileSetupCompleted, isTrue);
    expect(profile.level, 9);
  });

  test('a brand-new account still goes through setup', () async {
    profileBody = {'uuid': 'u2', 'name': 'New', 'email': 'n@example.com'};
    final profile = await make().getProfile('u2');
    expect(profile.profileSetupCompleted, isFalse);
  });

  test('a failed request falls back to the last profile', () async {
    final datasource = make();
    await datasource.getProfile('u1');

    offline = true;
    final profile = await datasource.getProfile('u1');
    expect(profile.profileSetupCompleted, isTrue);
    expect(profile.classLevel, '11th');
    expect(profile.level, 9);
  });

  test('with nothing saved, a failed request still fails', () async {
    offline = true;
    await expectLater(
      make().getProfile('u1'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('the tutorial flag survives an offline start', () async {
    final datasource = make();
    await datasource.getProfile('u1');
    offline = true;
    final profile = await datasource.completeTutorial(userId: 'u1');
    expect(profile.tutorialCompleted, isTrue);
    expect((await datasource.getProfile('u1')).tutorialCompleted, isTrue);
  });

  test('flags saved under the login id are found under another id', () async {
    // Setup was finished in a session known by the login id "login-id"...
    profileBody = {'uuid': 'u3', 'name': 'Sam', 'email': 's@example.com'};
    await storage.setString(StorageKeys.currentUserId, 'login-id');
    await make().completeTutorial(userId: 'login-id');

    // ...and later the session reports a different id for the same player.
    final profile = await make().getProfile('session-id');
    expect(profile.tutorialCompleted, isTrue);
  });
}
