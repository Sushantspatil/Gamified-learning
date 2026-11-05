import 'dart:convert';

import '../../../../../core/errors/app_exception.dart';
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
    try {
      final data = await _apiClient.get(ApiEndpoints.profile);
      final profile = _parseProfile(userId, data);
      await _cacheProfile(userId, profile);
      return profile;
    } on AuthException {
      rethrow;
    } catch (_) {
      // A slow or failed request must not make a set-up account look new:
      // fall back to the last profile the server sent.
      final cached = _cachedProfile(userId);
      if (cached != null) return cached;
      rethrow;
    }
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
    String? displayName,
  }) async {
    await _saveLocalProfileFields(
      userId: userId,
      classLevel: classLevel,
      board: board,
      selectedSubjectIds: selectedSubjectIds,
      profileSetupCompleted: true,
    );

    final local = _localProfileFields(userId);
    final userName =
        displayName ??
        (local['name'] as String?) ??
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
      final merged = <String, dynamic>{
        ...dto.toJson(),
        ..._localProfileFields(userId),
      };
      // The server only has a class and board once setup was finished, so
      // that is proof enough even when this phone lost its own saved flag.
      final hasDetails =
          (dto.classLevel ?? '').isNotEmpty && (dto.board ?? '').isNotEmpty;
      if (hasDetails) merged['profileSetupCompleted'] = true;
      return UserProfileModel.fromJson(merged);
    }
    throw const FormatException('Invalid profile response from backend.');
  }

  /// The ids this profile may be stored under: the one the session reports
  /// now, and the one saved at login. The two can differ, which used to make
  /// the saved "setup done" flag impossible to find again.
  List<String> _storageIds(String userId) {
    final loginId = _storage.getString(StorageKeys.currentUserId);
    return [if (loginId != null && loginId.isNotEmpty) loginId, userId];
  }

  Map<String, dynamic> _readJson(String key) {
    final encoded = _storage.getString(key);
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // A damaged entry counts as missing.
    }
    return const {};
  }

  Map<String, dynamic> _localProfileFields(String userId) {
    final merged = <String, dynamic>{};
    // The current session's id is read last, so it wins.
    for (final id in _storageIds(userId)) {
      merged.addAll(_readJson(StorageKeys.profileForUser(id)));
    }
    return merged;
  }

  Future<void> _cacheProfile(String userId, UserProfileModel profile) async {
    final encoded = jsonEncode(profile.toJson());
    for (final id in _storageIds(userId).toSet()) {
      await _storage.setString(StorageKeys.profileCacheForUser(id), encoded);
    }
  }

  UserProfileModel? _cachedProfile(String userId) {
    for (final id in _storageIds(userId).reversed) {
      final cached = _readJson(StorageKeys.profileCacheForUser(id));
      if (cached.isEmpty) continue;
      // Flags saved on this phone since (setup, tutorial) still apply.
      return UserProfileModel.fromJson({
        ...cached,
        ..._localProfileFields(userId),
      });
    }
    return null;
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

    final encoded = jsonEncode(updated);
    for (final id in _storageIds(userId).toSet()) {
      await _storage.setString(StorageKeys.profileForUser(id), encoded);
    }
  }
}
