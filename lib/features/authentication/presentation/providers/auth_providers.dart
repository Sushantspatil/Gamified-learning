import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/datasources/remote/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authDatasourceProvider = Provider<AuthDatasource>((ref) {
  return AuthRemoteDatasource(
    apiClient: ref.watch(apiClientProvider),
    storage: ref.watch(localStorageServiceProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authDatasourceProvider),
    ref.watch(localStorageServiceProvider),
  );
});

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() {
    return ref.watch(authRepositoryProvider).getCurrentUser();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue<AppUser?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
  }

  Future<bool> requestSignUpOtp({required String email}) async {
    state = const AsyncValue<AppUser?>.loading().copyWithPrevious(state);
    try {
      await ref.read(authRepositoryProvider).requestSignUpOtp(email: email);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required String otp,
  }) async {
    state = const AsyncValue<AppUser?>.loading().copyWithPrevious(state);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.verifySignUpOtp(email: email, otp: otp);
      final user = await repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AsyncValue.data(user);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }

  Future<void> updateDisplayName(String displayName) async {
    state = const AsyncValue<AppUser?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).updateDisplayName(displayName),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
