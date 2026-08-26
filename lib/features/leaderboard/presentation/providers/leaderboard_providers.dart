import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../data/datasources/leaderboard_datasource.dart';
import '../../data/datasources/mock/leaderboard_mock_datasource.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_filter.dart';
import '../../domain/repositories/leaderboard_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed LeaderboardDatasource
/// implementation when the backend is ready.
final leaderboardDatasourceProvider = Provider<LeaderboardDatasource>((ref) {
  return LeaderboardMockDatasource();
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepositoryImpl(ref.watch(leaderboardDatasourceProvider));
});

class LeaderboardFilterController extends Notifier<LeaderboardFilter> {
  @override
  LeaderboardFilter build() => const LeaderboardFilter();

  void setQuizType(QuestionType? quizType) {
    state = state.copyWith(quizType: quizType, clearQuizType: quizType == null);
  }

  void setSubject(String? subjectId) {
    state = state.copyWith(
      subjectId: subjectId,
      clearSubjectId: subjectId == null,
    );
  }

  void setTimeRange(LeaderboardTimeRange timeRange) {
    state = state.copyWith(timeRange: timeRange);
  }

  void setScope(LeaderboardScope scope) {
    state = state.copyWith(scope: scope);
  }
}

final leaderboardFilterProvider =
    NotifierProvider<LeaderboardFilterController, LeaderboardFilter>(
      LeaderboardFilterController.new,
    );

final globalLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((
  ref,
) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return const [];

  final profile = await ref.watch(profileControllerProvider.future);

  return ref
      .watch(leaderboardRepositoryProvider)
      .getGlobalLeaderboard(
        currentUserId: user.id,
        currentUserName: user.displayName,
        currentUserAvatarId: profile?.avatarId ?? 'default',
        currentUserXp: profile?.xp ?? 0,
      );
});

final filteredLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((
  ref,
) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return const [];

  final filter = ref.watch(leaderboardFilterProvider);
  final profile = await ref.watch(profileControllerProvider.future);

  return ref
      .watch(leaderboardRepositoryProvider)
      .getLeaderboard(
        filter: filter,
        currentUserId: user.id,
        currentUserName: user.displayName,
        currentUserAvatarId: profile?.avatarId ?? 'default',
        currentUserXp: profile?.xp ?? 0,
      );
});
