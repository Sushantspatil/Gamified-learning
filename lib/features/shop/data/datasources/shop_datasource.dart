import '../models/shop_item_model.dart';

/// Implemented today by [ShopMockDatasource]. Swap for a Firestore-backed
/// implementation (shopItems collection) later.
abstract class ShopDatasource {
  Future<List<ShopItemModel>> getShopItems();
}
