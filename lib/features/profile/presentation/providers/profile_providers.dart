import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/profile_datasource.dart';
import '../../data/datasources/remote/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// Backend profile binding.
final profileDatasourceProvider = Provider<ProfileDatasource>((ref) {
  return ProfileRemoteDatasource(
    apiClient: ref.watch(apiClientProvider),
    storage: ref.watch(localStorageServiceProvider),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileDatasourceProvider));
});

class ProfileController extends AsyncNotifier<UserProfile?> {
  Timer? _retryTimer;
  int _failedLoads = 0;

  @override
  Future<UserProfile?> build() async {
    ref.onDispose(() => _retryTimer?.cancel());
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return null;
    try {
      final profile = await ref
          .watch(profileRepositoryProvider)
          .getProfile(user.id);
      _failedLoads = 0;
      return profile;
    } catch (_) {
      // Try again shortly (a few times, a little slower each time) instead of
      // leaving the app without a profile until it is restarted.
      if (_failedLoads < 5) {
        _failedLoads++;
        _retryTimer?.cancel();
        _retryTimer = Timer(
          Duration(seconds: 2 * _failedLoads),
          ref.invalidateSelf,
        );
      }
      rethrow;
    }
  }

  Future<void> updateAvatar(String avatarId) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue<UserProfile?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref
          .read(profileRepositoryProvider)
          .updateAvatar(userId: user.id, avatarId: avatarId),
    );
  }

  Future<void> completeProfileSetup({
    required String avatarId,
    required String classLevel,
    required String board,
    required List<String> selectedSubjectIds,
  }) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue<UserProfile?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref
          .read(profileRepositoryProvider)
          .completeProfileSetup(
            userId: user.id,
            avatarId: avatarId,
            classLevel: classLevel,
            board: board,
            selectedSubjectIds: selectedSubjectIds,
            displayName: user.displayName,
          ),
    );
  }

  Future<void> completeTutorial() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue<UserProfile?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () =>
          ref.read(profileRepositoryProvider).completeTutorial(userId: user.id),
    );
  }

  /// Adds XP (from a finished quiz) and returns the resulting profile so
  /// callers can detect a level-up without re-reading state that may
  /// already be loading again.
  Future<UserProfile?> addXp(int xp) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return null;

    state = const AsyncValue<UserProfile?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).addXp(userId: user.id, xp: xp),
    );
    return state.valueOrNull;
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserProfile?>(
      ProfileController.new,
    );
