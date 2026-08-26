import '../../domain/entities/chest_result.dart';
import '../../domain/entities/chest_type.dart';
import '../../domain/repositories/chest_repository.dart';
import '../datasources/chest_datasource.dart';

class ChestRepositoryImpl implements ChestRepository {
  final ChestDatasource _datasource;

  ChestRepositoryImpl(this._datasource);

  @override
  Future<bool> isDailyChestAvailable(String userId) =>
      _datasource.isDailyChestAvailable(userId);

  @override
  Future<ChestResult> openChest(String userId, ChestType type) =>
      _datasource.openChest(userId, type);
}
