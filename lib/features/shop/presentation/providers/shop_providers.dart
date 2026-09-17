import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/shop_datasource.dart';
import '../../data/models/shop_item_model.dart';
import '../../data/repositories/shop_repository_impl.dart';
import '../../domain/entities/shop_item.dart';
import '../../domain/repositories/shop_repository.dart';

enum PurchaseResult { success, insufficientFunds }

/// Empty binding until the backend exposes shop data.
final shopDatasourceProvider = Provider<ShopDatasource>((ref) {
  return const EmptyShopDatasource();
});

class EmptyShopDatasource implements ShopDatasource {
  const EmptyShopDatasource();

  @override
  Future<List<ShopItemModel>> getShopItems() async {
    return const [];
  }
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepositoryImpl(ref.watch(shopDatasourceProvider));
});

final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) {
  return ref.watch(shopRepositoryProvider).getShopItems();
});

/// Orchestrates a purchase: decides credit vs. debit based on the item's
/// category and delegates the actual balance mutation to WalletController.
/// Holds no state of its own — the wallet balance is the single source of
/// truth.
class ShopPurchaseController extends Notifier<void> {
  @override
  void build() {}

  Future<PurchaseResult> purchase(ShopItem item) async {
    final wallet = ref.read(walletControllerProvider.notifier);

    switch (item.category) {
      case ShopItemCategory.gems:
      case ShopItemCategory.coins:
      case ShopItemCategory.adGems:
        await wallet.credit(
          currency: item.grantsCurrency!,
          amount: item.grantsAmount!,
          reason: item.title,
        );
        return PurchaseResult.success;
      case ShopItemCategory.powerup:
        final succeeded = await wallet.debit(
          currency: item.costCurrency!,
          amount: item.costAmount!,
          reason: 'Purchased: ${item.title}',
        );
        return succeeded
            ? PurchaseResult.success
            : PurchaseResult.insufficientFunds;
    }
  }
}

final shopPurchaseControllerProvider =
    NotifierProvider<ShopPurchaseController, void>(ShopPurchaseController.new);
