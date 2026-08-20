import '../../../../../core/constants/app_constants.dart';
import '../../../../wallet/domain/entities/currency_type.dart';
import '../../../domain/entities/shop_item.dart';
import '../../models/shop_item_model.dart';
import '../shop_datasource.dart';

/// MOCK DATA — replace the binding in shop_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Gem/coin
/// prices below are placeholder — no payment gateway is configured.
class ShopMockDatasource implements ShopDatasource {
  @override
  Future<List<ShopItemModel>> getShopItems() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return const [
      ShopItemModel(
        id: 'gems-small',
        title: '50 Gems',
        description: 'A small pouch of gems.',
        category: ShopItemCategory.gems,
        grantsCurrency: CurrencyType.gems,
        grantsAmount: 50,
        priceLabel: '\$0.99',
      ),
      ShopItemModel(
        id: 'gems-large',
        title: '150 Gems',
        description: 'A large pouch of gems.',
        category: ShopItemCategory.gems,
        grantsCurrency: CurrencyType.gems,
        grantsAmount: 150,
        priceLabel: '\$2.99',
      ),
      ShopItemModel(
        id: 'coins-small',
        title: '200 Coins',
        description: 'A small stack of coins.',
        category: ShopItemCategory.coins,
        grantsCurrency: CurrencyType.coins,
        grantsAmount: 200,
        priceLabel: '\$0.99',
      ),
      ShopItemModel(
        id: 'coins-large',
        title: '600 Coins',
        description: 'A large stack of coins.',
        category: ShopItemCategory.coins,
        grantsCurrency: CurrencyType.coins,
        grantsAmount: 600,
        priceLabel: '\$2.49',
      ),
      ShopItemModel(
        id: 'ad-gems',
        title: 'Watch an Ad',
        description: 'Watch a short ad to earn gems.',
        category: ShopItemCategory.adGems,
        grantsCurrency: CurrencyType.gems,
        grantsAmount: 10,
      ),
      ShopItemModel(
        id: 'powerup-streak-freeze',
        title: 'Streak Freeze',
        description: 'Protects your streak once.',
        category: ShopItemCategory.powerup,
        costCurrency: CurrencyType.gems,
        costAmount: AppConstants.streakFreezeCostGems,
      ),
    ];
  }
}
