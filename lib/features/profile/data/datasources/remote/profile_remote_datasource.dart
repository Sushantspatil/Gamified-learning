import 'dart:convert';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/network/dtos/profile_dtos.dart';
import '../../../../../core/storage/local_storage_service.dart';
import '../../../../../core/storage/storage_keys.dart';
import '../../models/user_profile_model.dart';
import '../profile_datasource.dart';

class ProfileRemoteDatasource implements ProfileDatasource {
  final ApiClient _apiClient;
  final LocalStorageService _storage;

  ProfileRemoteDatasource({
    required ApiClient apiClient,
    required LocalStorageService storage,
  }) : _apiClient = apiClient,
       _storage = storage;

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    final data = await _apiClient.get(ApiEndpoints.profile);
    return _parseProfile(userId, data);
  }

  @override
  Future<UserProfileModel> updateAvatar({
    required String userId,
    required String avatarId,
  }) async {
    final requestDto = ProfileUpdateRequestDto(
      avatarId: avatarId,
      avatarUrl: avatarId,
    );
    final data = await _apiClient.put(
      ApiEndpoints.profile,
      body: requestDto.toJson(),
    );
    return _parseProfile(userId, data);
  }

  @override
  Future<UserProfileModel> completeProfileSetup({
    required String userId,
    required String avatarId,
    required String classLevel,
    required String board,
    required List<String> selectedSubjectIds,
  }) async {
    await _saveLocalProfileFields(
      userId: userId,
      classLevel: classLevel,
      board: board,
      selectedSubjectIds: selectedSubjectIds,
      profileSetupCompleted: true,
    );

    final local = _localProfileFields(userId);
    final userName = (local['name'] as String?) ??
        (local['displayName'] as String?) ??
        (local['username'] as String?) ??
        'Student';

    final requestDto = ProfileSetupRequestDto(
      avatarId: avatarId,
      name: userName,
      classLevel: classLevel,
      board: board,
      subjects: selectedSubjectIds,
    );

    final data = await _apiClient.post(
      ApiEndpoints.profileSetup,
      body: requestDto.toJson(),
    );
    return _parseProfile(userId, data);
  }

  @override
  Future<UserProfileModel> completeTutorial({required String userId}) async {
    await _saveLocalProfileFields(userId: userId, tutorialCompleted: true);
    return getProfile(userId);
  }

  @override
  Future<UserProfileModel> addXp({required String userId, required int xp}) =>
      getProfile(userId);

  UserProfileModel _parseProfile(String userId, dynamic data) {
    if (data is Map<String, dynamic>) {
      final dto = ProfileResponseDto.fromJson(data);
      return UserProfileModel.fromJson({
        ...dto.toJson(),
        ..._localProfileFields(userId),
      });
    }
    throw const FormatException('Invalid profile response from backend.');
  }

  Map<String, dynamic> _localProfileFields(String userId) {
    final encoded = _storage.getString(StorageKeys.profileForUser(userId));
    if (encoded == null || encoded.isEmpty) return const {};

    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  }

  Future<void> _saveLocalProfileFields({
    required String userId,
    String? classLevel,
    String? board,
    List<String>? selectedSubjectIds,
    bool? profileSetupCompleted,
    bool? tutorialCompleted,
  }) async {
    final current = _localProfileFields(userId);
    final updated = <String, dynamic>{...current};
    if (classLevel != null) updated['classLevel'] = classLevel;
    if (board != null) updated['board'] = board;
    if (selectedSubjectIds != null) {
      updated['selectedSubjectIds'] = selectedSubjectIds;
    }
    if (profileSetupCompleted != null) {
      updated['profileSetupCompleted'] = profileSetupCompleted;
    }
    if (tutorialCompleted != null) {
      updated['tutorialCompleted'] = tutorialCompleted;
    }

    await _storage.setString(
      StorageKeys.profileForUser(userId),
      jsonEncode(updated),
    );
  }
}
