import '../entities/cosmetic_item.dart';

/// Purchasing debits coins via WalletRepository (orchestrated by
/// CosmeticsController, not here) — this repository only tracks the
/// catalog and per-user ownership/equipped state.
abstract class CosmeticsRepository {
  Future<List<CosmeticItem>> getCatalog();

  Future<Set<String>> getOwnedCosmeticIds(String userId);

  Future<String?> getEquippedCosmeticId(String userId);

  Future<void> recordPurchase(String userId, String cosmeticId);

  /// Throws a ValidationException if the cosmetic isn't owned.
  Future<void> setEquipped(String userId, String cosmeticId);
}
