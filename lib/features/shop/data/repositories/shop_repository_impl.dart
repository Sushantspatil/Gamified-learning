import '../../domain/entities/shop_item.dart';
import '../../domain/repositories/shop_repository.dart';
import '../datasources/shop_datasource.dart';

class ShopRepositoryImpl implements ShopRepository {
  final ShopDatasource _datasource;

  ShopRepositoryImpl(this._datasource);

  @override
  Future<List<ShopItem>> getShopItems() => _datasource.getShopItems();
}
