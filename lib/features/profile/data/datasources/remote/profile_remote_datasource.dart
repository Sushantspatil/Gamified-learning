import '../../../../../core/network/api_client.dart';
import '../../models/user_profile_model.dart';
import '../profile_datasource.dart';

class ProfileRemoteDatasource implements ProfileDatasource {
  final ApiClient _apiClient;

  ProfileRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    final data = await _apiClient.get('/profile');
    return _parseProfile(data);
  }

  @override
  Future<UserProfileModel> updateAvatar({
    required String userId,
    required String avatarId,
  }) async {
    final data = await _apiClient.put(
      '/profile',
      body: {'avatarUrl': avatarId},
    );
    return _parseProfile(data);
  }

  @override
  Future<UserProfileModel> completeProfileSetup({
    required String userId,
    required String avatarId,
    required String classLevel,
    required String board,
    required List<String> selectedSubjectIds,
  }) async {
    final data = await _apiClient.put(
      '/profile',
      body: {
        'avatarUrl': avatarId,
        'classLevel': classLevel,
        'board': board,
        'selectedSubjectIds': selectedSubjectIds,
        'profileSetupCompleted': true,
      },
    );
    return _parseProfile(data);
  }

  @override
  Future<UserProfileModel> completeTutorial({required String userId}) async {
    final data = await _apiClient.put(
      '/profile',
      body: {'tutorialCompleted': true},
    );
    return _parseProfile(data);
  }

  @override
  Future<UserProfileModel> addXp({required String userId, required int xp}) =>
      getProfile(userId);

  UserProfileModel _parseProfile(dynamic data) {
    if (data is Map<String, dynamic>) {
      return UserProfileModel.fromJson(data);
    }
    throw const FormatException('Invalid profile response from backend.');
  }
}
