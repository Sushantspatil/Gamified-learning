import '../../../../../core/errors/app_exception.dart';
import '../../models/user_model.dart';
import '../auth_datasource.dart';

/// Temporary in-memory stand-in for a Firebase Auth + Firestore backed
/// datasource. Simulates network latency and validation so the UI/state
/// layers behave the same way they will once a real backend is wired in.
///
/// MOCK DATA — replace the binding in auth_providers.dart with a Firebase
/// implementation when the backend is ready. Do not extend this class with
/// production logic.
class AuthMockDatasource implements AuthDatasource {
  final Map<String, String> _passwordsByEmail = {};
  final Map<String, UserModel> _usersByEmail = {};
  int _nextId = 1;

  AuthMockDatasource() {
    // Pre-seed a default user for testing
    const defaultEmail = 'test@example.com';
    const defaultPassword = 'password123';
    _usersByEmail[defaultEmail] = const UserModel(
      id: 'mock-user-0',
      email: defaultEmail,
      displayName: 'Test User',
    );
    _passwordsByEmail[defaultEmail] = defaultPassword;
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final storedPassword = _passwordsByEmail[email];
    if (storedPassword == null) {
      throw const AuthException(
        'No account found for this email.',
        'user-not-found',
      );
    }
    if (storedPassword != password) {
      throw const AuthException('Incorrect password.', 'wrong-password');
    }
    return _usersByEmail[email]!;
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (_usersByEmail.containsKey(email)) {
      throw const AuthException(
        'An account already exists for this email.',
        'email-in-use',
      );
    }

    final user = UserModel(
      id: 'mock-user-${_nextId++}',
      email: email,
      displayName: displayName,
    );
    _usersByEmail[email] = user;
    _passwordsByEmail[email] = password;
    return user;
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final user in _usersByEmail.values) {
      if (user.id == id) return user;
    }
    return null;
  }

  @override
  Future<UserModel> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final email = _usersByEmail.entries
        .firstWhere((entry) => entry.value.id == userId)
        .key;
    final updated = UserModel(
      id: userId,
      email: email,
      displayName: displayName,
    );
    _usersByEmail[email] = updated;
    return updated;
  }
}
