import '../../domain/entities/cosmetic_item.dart';
import '../../domain/repositories/cosmetics_repository.dart';
import '../datasources/cosmetics_datasource.dart';

class CosmeticsRepositoryImpl implements CosmeticsRepository {
  final CosmeticsDatasource _datasource;

  CosmeticsRepositoryImpl(this._datasource);

  @override
  Future<List<CosmeticItem>> getCatalog() => _datasource.getCatalog();

  @override
  Future<Set<String>> getOwnedCosmeticIds(String userId) => _datasource.getOwnedCosmeticIds(userId);

  @override
  Future<String?> getEquippedCosmeticId(String userId) => _datasource.getEquippedCosmeticId(userId);

  @override
  Future<void> recordPurchase(String userId, String cosmeticId) =>
      _datasource.recordPurchase(userId, cosmeticId);

  @override
  Future<void> setEquipped(String userId, String cosmeticId) =>
      _datasource.setEquipped(userId, cosmeticId);
}
