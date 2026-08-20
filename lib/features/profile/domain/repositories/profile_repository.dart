import '../entities/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getProfile(String userId);

  Future<UserProfile> updateAvatar({required String userId, required String avatarId});

  /// Adds XP (e.g. from a finished quiz) and recomputes level from the new
  /// total. Once a backend exists, this call becomes a request the server
  /// verifies and recomputes independently — see Step 10 anti-tampering
  /// requirements. Coins/gems are not handled here — see WalletRepository.
  Future<UserProfile> addXp({required String userId, required int xp});
}
