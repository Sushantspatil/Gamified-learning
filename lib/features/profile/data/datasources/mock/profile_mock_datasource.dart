import '../../../../../core/utils/level_calculator.dart';
import '../../models/user_profile_model.dart';
import '../profile_datasource.dart';

/// MOCK DATA — replace the binding in profile_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Do not extend
/// this class with production logic (in particular, real XP mutations
/// belong to Cloud Functions once the backend lands).
class ProfileMockDatasource implements ProfileDatasource {
  final Map<String, UserProfileModel> _profilesByUserId = {};

  UserProfileModel _defaultProfileFor(String userId) {
    if (userId == 'mock-user-0') {
      return const UserProfileModel(
        avatarId: 'default',
        classLevel: '12th',
        board: 'Maharashtra State Board',
        selectedSubjectIds: ['web-dev'],
        profileSetupCompleted: true,
        tutorialCompleted: true,
        xp: 0,
        level: 1,
      );
    }
    return const UserProfileModel(avatarId: 'default', xp: 0, level: 1);
  }

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _profilesByUserId[userId] ?? _defaultProfileFor(userId);
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
      classLevel: current.classLevel,
      board: current.board,
      selectedSubjectIds: current.selectedSubjectIds,
      profileSetupCompleted: current.profileSetupCompleted,
      tutorialCompleted: current.tutorialCompleted,
      xp: current.xp,
      level: current.level,
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }

  @override
  Future<UserProfileModel> completeProfileSetup({
    required String userId,
    required String avatarId,
    required String classLevel,
    required String board,
    required List<String> selectedSubjectIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = await getProfile(userId);
    final updated = UserProfileModel(
      avatarId: avatarId,
      classLevel: classLevel,
      board: board,
      selectedSubjectIds: selectedSubjectIds,
      profileSetupCompleted: true,
      tutorialCompleted: current.tutorialCompleted,
      xp: current.xp,
      level: current.level,
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }

  @override
  Future<UserProfileModel> completeTutorial({required String userId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = await getProfile(userId);
    final updated = UserProfileModel(
      avatarId: current.avatarId,
      classLevel: current.classLevel,
      board: current.board,
      selectedSubjectIds: current.selectedSubjectIds,
      profileSetupCompleted: current.profileSetupCompleted,
      tutorialCompleted: true,
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
      classLevel: current.classLevel,
      board: current.board,
      selectedSubjectIds: current.selectedSubjectIds,
      profileSetupCompleted: current.profileSetupCompleted,
      tutorialCompleted: current.tutorialCompleted,
      xp: newXp,
      level: LevelCalculator.levelForXp(newXp),
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }
}
