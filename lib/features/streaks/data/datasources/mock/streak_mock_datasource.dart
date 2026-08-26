import '../../../../../core/utils/date_key.dart';
import '../../models/streak_model.dart';
import '../streak_datasource.dart';

/// MOCK DATA — replace the binding in streak_providers.dart with a
/// Firestore-backed implementation when the backend is ready.
class StreakMockDatasource implements StreakDatasource {
  final Map<String, StreakModel> _streaksByUserId = {};

  @override
  Future<StreakModel> getStreak(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _streaksByUserId[userId] ??
        const StreakModel(currentStreak: 0, lastActiveDateKey: null);
  }

  @override
  Future<StreakModel> recordAppOpen(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final today = dateKey(DateTime.now());
    final current = await getStreak(userId);

    if (current.lastActiveDateKey == today) {
      return current; // already recorded today
    }

    final yesterday = dateKey(DateTime.now().subtract(const Duration(days: 1)));
    final newStreak = current.lastActiveDateKey == yesterday
        ? current.currentStreak + 1
        : 1;

    final updated = StreakModel(
      currentStreak: newStreak,
      lastActiveDateKey: today,
    );
    _streaksByUserId[userId] = updated;
    return updated;
  }
}
