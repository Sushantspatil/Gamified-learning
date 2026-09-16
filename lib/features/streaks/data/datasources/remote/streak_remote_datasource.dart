import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/streak_model.dart';
import '../streak_datasource.dart';

class StreakRemoteDatasource implements StreakDatasource {
  final ApiClient _apiClient;

  StreakRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<StreakModel> getStreak(String userId) async {
    final data = await _apiClient.get('/profile');
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid streak response from backend.');
    }

    String? lastActiveDate;
    final history = data['last7DaysStreak'];
    if (history is List) {
      for (final item in history.reversed) {
        if (item is Map<String, dynamic> && item['completed'] == true) {
          lastActiveDate = item['date']?.toString();
          break;
        }
      }
    }

    return StreakModel(
      currentStreak: data['streaks'] as int? ?? 0,
      lastActiveDateKey: lastActiveDate,
    );
  }

  @override
  Future<StreakModel> recordAppOpen(String userId) => getStreak(userId);
}
