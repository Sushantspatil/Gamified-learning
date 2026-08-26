import '../models/user_model.dart';

/// Implemented today by [AuthMockDatasource]. Swap the provider binding to a
/// Firebase-backed implementation later without changing the repository.
abstract class AuthDatasource {
  Future<UserModel> login({required String email, required String password});

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<UserModel?> getUserById(String id);

  Future<UserModel> updateDisplayName({
    required String userId,
    required String displayName,
  });
}
