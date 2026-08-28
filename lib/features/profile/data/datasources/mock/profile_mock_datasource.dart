import '../../../../../core/utils/level_calculator.dart';
import '../../models/user_profile_model.dart';
import '../profile_datasource.dart';

/// MOCK DATA — replace the binding in profile_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Do not extend
/// this class with production logic (in particular, real XP mutations
/// belong to Cloud Functions once the backend lands).
class ProfileMockDatasource implements ProfileDatasource {
  final Map<String, UserProfileModel> _profilesByUserId = {};

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _profilesByUserId[userId] ??
        const UserProfileModel(avatarId: 'default', xp: 0, level: 1);
  }

  @override
  Future<UserProfileModel> updateAvatar({
    required String userId,
    required String avatarId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = await getProfile(userId);
    final updated = UserProfileModel(
      avatarId: avatarId,
      xp: current.xp,
      level: current.level,
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }

  @override
  Future<UserProfileModel> addXp({
    required String userId,
    required int xp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = await getProfile(userId);
    final newXp = current.xp + xp;
    final updated = UserProfileModel(
      avatarId: current.avatarId,
      xp: newXp,
      level: LevelCalculator.levelForXp(newXp),
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }
}
