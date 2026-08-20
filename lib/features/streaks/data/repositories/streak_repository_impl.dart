import '../../domain/entities/streak.dart';
import '../../domain/repositories/streak_repository.dart';
import '../datasources/streak_datasource.dart';

class StreakRepositoryImpl implements StreakRepository {
  final StreakDatasource _datasource;

  StreakRepositoryImpl(this._datasource);

  @override
  Future<Streak> getStreak(String userId) => _datasource.getStreak(userId);

  @override
  Future<Streak> recordAppOpen(String userId) => _datasource.recordAppOpen(userId);
}
