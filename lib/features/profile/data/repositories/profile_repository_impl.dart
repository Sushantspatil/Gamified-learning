import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileDatasource _datasource;

  ProfileRepositoryImpl(this._datasource);

  @override
  Future<UserProfile> getProfile(String userId) => _datasource.getProfile(userId);

  @override
  Future<UserProfile> updateAvatar({required String userId, required String avatarId}) {
    return _datasource.updateAvatar(userId: userId, avatarId: avatarId);
  }

  @override
  Future<UserProfile> addXp({required String userId, required int xp}) {
    return _datasource.addXp(userId: userId, xp: xp);
  }
}
