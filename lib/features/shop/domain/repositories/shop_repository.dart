import '../entities/shop_item.dart';

/// Catalog only — purchases are never handled here. Granting currency or
/// charging for a powerup goes through WalletRepository (the single
/// authority for balance mutations), orchestrated by ShopPurchaseController.
abstract class ShopRepository {
  Future<List<ShopItem>> getShopItems();
}
