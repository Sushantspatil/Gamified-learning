import '../models/user_profile_model.dart';

/// Implemented today by [ProfileMockDatasource]. Swap for a Firestore-backed
/// implementation (users collection) later. Coin/gem/XP balances read here
/// must eventually be treated as server-authoritative — see wallet/economy
/// stage — this datasource is not where balances get mutated once a real
/// backend exists.
abstract class ProfileDatasource {
  Future<UserProfileModel> getProfile(String userId);

  Future<UserProfileModel> updateAvatar({
    required String userId,
    required String avatarId,
  });

  Future<UserProfileModel> addXp({required String userId, required int xp});
}
