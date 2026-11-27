import '../models/user_model.dart';

/// Implemented by [AuthRemoteDatasource] (the backend). Tests use a mock
/// from `test/mocks/`.
abstract class AuthDatasource {
  Future<UserModel> login({required String email, required String password});

  Future<String?> requestSignUpOtp({
    required String email,
    String? password,
    String? displayName,
  });

  Future<String?> resendSignUpOtp({required String email});

  Future<void> verifySignUpOtp({required String email, required String otp});

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<UserModel?> getUserById(String id);

  Future<void> logout();

  Future<UserModel> updateDisplayName({
    required String userId,
    required String displayName,
  });
}
