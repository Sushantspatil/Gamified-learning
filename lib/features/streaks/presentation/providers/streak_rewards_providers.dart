import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/remote/streak_rewards_remote_datasource.dart';
import '../../domain/entities/streak_rewards.dart';

final streakRewardsDatasourceProvider = Provider<StreakRewardsRemoteDatasource>(
  (ref) {
    return StreakRewardsRemoteDatasource(
      apiClient: ref.watch(apiClientProvider),
    );
  },
);

/// The streak milestone rewards, or null when there is nothing to show (nobody
/// signed in, or a server without streak rewards).
class StreakRewardsController extends AsyncNotifier<StreakRewards?> {
  @override
  Future<StreakRewards?> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return null;
    return ref.watch(streakRewardsDatasourceProvider).fetch();
  }

  /// Collects a milestone's reward. Returns null on success, or a short message
  /// to show the player. Either way the rewards and the balance are re-read, so
  /// "already claimed" simply shows as claimed.
  Future<String?> claim(int days) async {
    String? problem;
    try {
      await ref.read(streakRewardsDatasourceProvider).claim(days);
    } on ValidationException catch (e) {
      problem = e.message;
    } on AppException {
      problem = 'Could not collect the reward. Please try again.';
    }

    try {
      state = AsyncValue.data(
        await ref.read(streakRewardsDatasourceProvider).fetch(),
      );
    } on AppException {
      // Leave what is shown; the next refresh will catch up.
    }
    // The server paid the account: refresh the balance every screen shows.
    ref.invalidate(walletControllerProvider);
    return problem;
  }
}

final streakRewardsControllerProvider =
    AsyncNotifierProvider<StreakRewardsController, StreakRewards?>(
      StreakRewardsController.new,
    );
