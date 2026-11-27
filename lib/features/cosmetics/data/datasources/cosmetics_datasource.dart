import '../models/cosmetic_item_model.dart';

/// The app binds `EmptyCosmeticsDatasource`; tests use a mock from
/// `test/mocks/`.
abstract class CosmeticsDatasource {
  Future<List<CosmeticItemModel>> getCatalog();

  Future<Set<String>> getOwnedCosmeticIds(String userId);

  Future<String?> getEquippedCosmeticId(String userId);

  Future<void> recordPurchase(String userId, String cosmeticId);

  Future<void> setEquipped(String userId, String cosmeticId);
}
