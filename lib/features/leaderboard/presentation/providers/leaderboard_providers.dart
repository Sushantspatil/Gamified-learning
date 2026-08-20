import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/leaderboard_datasource.dart';
import '../../data/datasources/mock/leaderboard_mock_datasource.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed LeaderboardDatasource
/// implementation when the backend is ready.
final leaderboardDatasourceProvider = Provider<LeaderboardDatasource>((ref) {
  return LeaderboardMockDatasource();
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepositoryImpl(ref.watch(leaderboardDatasourceProvider));
});

final globalLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return const [];

  final profile = await ref.watch(profileControllerProvider.future);

  return ref.watch(leaderboardRepositoryProvider).getGlobalLeaderboard(
        currentUserId: user.id,
        currentUserName: user.displayName,
        currentUserAvatarId: profile?.avatarId ?? 'default',
        currentUserXp: profile?.xp ?? 0,
      );
});
