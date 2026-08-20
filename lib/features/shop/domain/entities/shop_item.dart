import 'package:equatable/equatable.dart';

import '../../../wallet/domain/entities/currency_type.dart';

enum ShopItemCategory { gems, coins, adGems, powerup }

class ShopItem extends Equatable {
  final String id;
  final String title;
  final String description;
  final ShopItemCategory category;

  /// Set for gems/coins/adGems items: what the player receives.
  final CurrencyType? grantsCurrency;
  final int? grantsAmount;

  /// Display-only price for gems/coins packs — no payment gateway is
  /// configured, so purchasing these is a clearly-labeled demo transaction,
  /// never a real charge.
  final String? priceLabel;

  /// Set for powerup items: what it costs in existing wallet currency.
  final CurrencyType? costCurrency;
  final int? costAmount;

  const ShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.grantsCurrency,
    this.grantsAmount,
    this.priceLabel,
    this.costCurrency,
    this.costAmount,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        grantsCurrency,
        grantsAmount,
        priceLabel,
        costCurrency,
        costAmount,
      ];
}
