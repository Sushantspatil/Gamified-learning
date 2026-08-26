import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/utils/date_key.dart';
import '../../models/daily_reward_model.dart';
import '../daily_reward_datasource.dart';

/// Placeholder 7-day reward cycle — not specified by the product
/// requirements. Cycles back to day 1 after day 7.
const List<int> _coinsByCycleDay = [10, 15, 20, 25, 30, 40, 60];

/// MOCK DATA — replace the binding in daily_reward_providers.dart with a
/// Firestore-backed implementation when the backend is ready.
class DailyRewardMockDatasource implements DailyRewardDatasource {
  final Map<String, String> _claimedDateKeyByUser = {};

  int _coinsForCycleDay(int streakDay) {
    final index = (streakDay - 1) % _coinsByCycleDay.length;
    return _coinsByCycleDay[index];
  }

  @override
  Future<DailyRewardModel> getTodayReward(String userId, int streakDay) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final today = dateKey(DateTime.now());
    return DailyRewardModel(
      cycleDay: streakDay,
      coins: _coinsForCycleDay(streakDay),
      claimedToday: _claimedDateKeyByUser[userId] == today,
    );
  }

  @override
  Future<DailyRewardModel> claimTodayReward(
    String userId,
    int streakDay,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final today = dateKey(DateTime.now());

    if (_claimedDateKeyByUser[userId] == today) {
      throw const ValidationException(
        "Today's reward has already been claimed.",
        'already-claimed',
      );
    }

    _claimedDateKeyByUser[userId] = today;
    return DailyRewardModel(
      cycleDay: streakDay,
      coins: _coinsForCycleDay(streakDay),
      claimedToday: true,
    );
  }
}
