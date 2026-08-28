import 'package:equatable/equatable.dart';

import '../../../wallet/domain/entities/currency_type.dart';
import 'chest_type.dart';

/// The reward is decided entirely by ChestRepository before this entity
/// exists — the UI only reveals it, never rolls its own outcome. Once a
/// backend exists, that decision moves server-side (Step 10) without this
/// shape changing.
class ChestResult extends Equatable {
  final ChestType chestType;
  final CurrencyType currency;
  final int amount;

  const ChestResult({
    required this.chestType,
    required this.currency,
    required this.amount,
  });

  @override
  List<Object?> get props => [chestType, currency, amount];
}
