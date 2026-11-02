import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/profile/data/datasources/mock/profile_mock_datasource.dart';
import 'package:skillverse_app/features/profile/data/datasources/remote/profile_remote_datasource.dart';
import 'package:skillverse_app/features/profile/data/models/user_profile_model.dart';
import 'package:skillverse_app/features/profile/presentation/providers/profile_providers.dart';

/// The backend now stores the name sent to POST /profile/setup, so the app must
/// send the user's real display name, never a placeholder.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('profile setup posts the real display name', () async {
    final storage = await LocalStorageService.create();
    final bodies = <Map<String, dynamic>>[];
    final api = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test/api/v1'),
      storage: storage,
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'uuid': 'u1', 'name': 'Real Name', 'email': 'a@b.c'},
          }),
          200,
        );
      }),
    );
    final remote = ProfileRemoteDatasource(apiClient: api, storage: storage);

    await remote.completeProfileSetup(
      userId: 'u1',
      avatarId: 'default',
      classLevel: '12th',
      board: 'Maharashtra State Board',
      selectedSubjectIds: const ['accounting'],
      displayName: 'Real Name',
    );

    expect(bodies.single['name'], 'Real Name');
    expect(bodies.single['name'], isNot('Student'));
  });

  test('ProfileController passes the signed-in user name to setup', () async {
    final storage = await LocalStorageService.create();
    final profiles = _RecordingProfiles();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        profileDatasourceProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'test@example.com', password: 'password123');

    await container
        .read(profileControllerProvider.notifier)
        .completeProfileSetup(
          avatarId: 'default',
          classLevel: '12th',
          board: 'Maharashtra State Board',
          selectedSubjectIds: const ['accounting'],
        );

    expect(profiles.lastDisplayName, 'Test User');
  });
}

class _RecordingProfiles extends ProfileMockDatasource {
  String? lastDisplayName;

  @override
  Future<UserProfileModel> completeProfileSetup({
    required String userId,
    required String avatarId,
    required String classLevel,
    required String board,
    required List<String> selectedSubjectIds,
    String? displayName,
  }) {
    lastDisplayName = displayName;
    return super.completeProfileSetup(
      userId: userId,
      avatarId: avatarId,
      classLevel: classLevel,
      board: board,
      selectedSubjectIds: selectedSubjectIds,
      displayName: displayName,
    );
  }
}
