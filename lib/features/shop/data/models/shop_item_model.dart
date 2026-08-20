import '../../domain/entities/shop_item.dart';

class ShopItemModel extends ShopItem {
  const ShopItemModel({
    required super.id,
    required super.title,
    required super.description,
    required super.category,
    super.grantsCurrency,
    super.grantsAmount,
    super.priceLabel,
    super.costCurrency,
    super.costAmount,
  });
}
