import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/mock/streak_mock_datasource.dart';
import '../../data/datasources/streak_datasource.dart';
import '../../data/repositories/streak_repository_impl.dart';
import '../../domain/entities/streak.dart';
import '../../domain/repositories/streak_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed StreakDatasource
/// implementation when the backend is ready.
final streakDatasourceProvider = Provider<StreakDatasource>((ref) {
  return StreakMockDatasource();
});

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepositoryImpl(ref.watch(streakDatasourceProvider));
});

/// Recording "app opened today" happens as part of loading the streak, so
/// the Dashboard just watches this provider and the streak updates itself
/// — no separate side-effecting call needed from the UI.
class StreakController extends AsyncNotifier<Streak> {
  @override
  Future<Streak> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return Streak.empty;
    return ref.watch(streakRepositoryProvider).recordAppOpen(user.id);
  }
}

final streakControllerProvider = AsyncNotifierProvider<StreakController, Streak>(
  StreakController.new,
);
