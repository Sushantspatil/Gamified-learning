import 'package:equatable/equatable.dart';

import '../../../wallet/domain/entities/currency_type.dart';

class SpinWheelSegment extends Equatable {
  final String id;
  final CurrencyType currency;
  final int amount;

  const SpinWheelSegment({
    required this.id,
    required this.currency,
    required this.amount,
  });

  String get label =>
      '$amount ${currency == CurrencyType.coins ? 'Coins' : 'Gems'}';

  @override
  List<Object?> get props => [id, currency, amount];
}
