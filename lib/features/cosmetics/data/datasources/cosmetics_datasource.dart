import '../models/cosmetic_item_model.dart';

/// Implemented today by [CosmeticsMockDatasource]. Swap for a
/// Firestore-backed implementation (cosmetics collection) later.
abstract class CosmeticsDatasource {
  Future<List<CosmeticItemModel>> getCatalog();

  Future<Set<String>> getOwnedCosmeticIds(String userId);

  Future<String?> getEquippedCosmeticId(String userId);

  Future<void> recordPurchase(String userId, String cosmeticId);

  Future<void> setEquipped(String userId, String cosmeticId);
}
