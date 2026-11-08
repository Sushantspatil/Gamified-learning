import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../domain/entities/streak_rewards.dart';

/// Streak milestone rewards from the backend (`GET /streak`, `POST /streak/claim`).
class StreakRewardsRemoteDatasource {
  final ApiClient _apiClient;

  StreakRewardsRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  /// Null when the server has no streak rewards (yet), so the app shows nothing.
  Future<StreakRewards?> fetch() async {
    final dynamic data;
    try {
      data = await _apiClient.get(ApiEndpoints.streak);
    } on NotFoundException {
      return null;
    }
    return parse(data);
  }

  Future<void> claim(int days) async {
    await _apiClient.post(ApiEndpoints.streakClaim, body: {'days': days});
  }

  /// Reads the response. A row missing what the card needs is skipped, so one
  /// bad row cannot hide the others.
  static StreakRewards? parse(Object? data) {
    if (data is! Map) return null;
    final current = data['current'];
    final rows = data['milestones'];
    if (current is! num || rows is! List) return null;

    final milestones = <StreakMilestone>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final days = row['days'];
      final reward = row['reward'];
      if (days is! num || reward is! num) continue;
      milestones.add(
        StreakMilestone(
          days: days.toInt(),
          currency: row['currency'] == 'gems' ? 'gems' : 'coins',
          reward: reward.toInt(),
          reached: row['reached'] == true,
          claimed: row['claimed'] == true,
        ),
      );
    }
    return StreakRewards(
      currentStreak: current.toInt(),
      milestones: milestones,
    );
  }
}
