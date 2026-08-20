import '../entities/app_user.dart';

/// Contract the presentation layer depends on. Data layer swaps the
/// implementation from a mock datasource to Firebase without touching
/// controllers or UI.
abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();

  Future<AppUser> login({required String email, required String password});

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> logout();

  Future<AppUser> updateDisplayName(String displayName);
}
