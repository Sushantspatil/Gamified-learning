import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDatasource _datasource;
  final LocalStorageService _storage;

  AuthRepositoryImpl(this._datasource, this._storage);

  @override
  Future<AppUser?> getCurrentUser() async {
    final id = _storage.getString(StorageKeys.currentUserId);
    if (id == null) return null;
    return _datasource.getUserById(id);
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final user = await _datasource.login(email: email, password: password);
    await _storage.setString(StorageKeys.currentUserId, user.id);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await _datasource.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _storage.setString(StorageKeys.currentUserId, user.id);
    return user;
  }

  @override
  Future<void> logout() async {
    await _storage.remove(StorageKeys.currentUserId);
  }

  @override
  Future<AppUser> updateDisplayName(String displayName) async {
    final id = _storage.getString(StorageKeys.currentUserId);
    if (id == null) {
      throw const AuthException(
        'No user is currently logged in.',
        'no-current-user',
      );
    }
    return _datasource.updateDisplayName(userId: id, displayName: displayName);
  }
}
