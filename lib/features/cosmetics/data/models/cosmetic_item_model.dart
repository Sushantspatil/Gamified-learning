import '../../domain/entities/cosmetic_item.dart';

class CosmeticItemModel extends CosmeticItem {
  const CosmeticItemModel({
    required super.id,
    required super.name,
    required super.colorKey,
    required super.costCoins,
  });
}
