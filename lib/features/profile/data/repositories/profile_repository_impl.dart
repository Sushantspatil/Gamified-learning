import 'dart:convert';

import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/utils/level_calculator.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_datasource.dart';
import '../models/user_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileDatasource _datasource;
  final LocalStorageService _storage;

  ProfileRepositoryImpl(this._datasource, this._storage);

  @override
  Future<UserProfile> getProfile(String userId) async {
    final stored = _storage.getString(StorageKeys.profileForUser(userId));
    if (stored != null) {
      return UserProfileModel.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    }
    final profile = await _datasource.getProfile(userId);
    await _persist(userId, profile);
    return profile;
  }

  @override
  Future<UserProfile> updateAvatar({
    required String userId,
    required String avatarId,
  }) async {
    final current = await getProfile(userId);
    final updated = UserProfileModel.fromEntity(
      current.copyWith(avatarId: avatarId),
    );
    await _persist(userId, updated);
    return updated;
  }

  @override
  Future<UserProfile> completeProfileSetup({
    required String userId,
    required String avatarId,
    required String classLevel,
    required String board,
    required List<String> selectedSubjectIds,
  }) async {
    final current = await getProfile(userId);
    final updated = UserProfileModel.fromEntity(
      current.copyWith(
        avatarId: avatarId,
        classLevel: classLevel,
        board: board,
        selectedSubjectIds: selectedSubjectIds,
        profileSetupCompleted: true,
      ),
    );
    await _persist(userId, updated);
    return updated;
  }

  @override
  Future<UserProfile> completeTutorial({required String userId}) async {
    final current = await getProfile(userId);
    final updated = UserProfileModel.fromEntity(
      current.copyWith(tutorialCompleted: true),
    );
    await _persist(userId, updated);
    return updated;
  }

  @override
  Future<UserProfile> addXp({required String userId, required int xp}) async {
    final current = await getProfile(userId);
    final newXp = current.xp + xp;
    final updated = UserProfileModel.fromEntity(
      current.copyWith(xp: newXp, level: LevelCalculator.levelForXp(newXp)),
    );
    await _persist(userId, updated);
    return updated;
  }

  Future<void> _persist(String userId, UserProfile profile) async {
    await _storage.setString(
      StorageKeys.profileForUser(userId),
      jsonEncode(UserProfileModel.fromEntity(profile).toJson()),
    );
  }
}
