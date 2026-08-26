import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/mock/profile_mock_datasource.dart';
import '../../data/datasources/profile_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed ProfileDatasource
/// implementation when the backend is ready.
final profileDatasourceProvider = Provider<ProfileDatasource>((ref) {
  return ProfileMockDatasource();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileDatasourceProvider));
});

class ProfileController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return null;
    return ref.watch(profileRepositoryProvider).getProfile(user.id);
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
