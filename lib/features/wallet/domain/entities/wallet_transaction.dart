import 'package:equatable/equatable.dart';

import 'currency_type.dart';

enum TransactionDirection { credit, debit }

/// One entry in the auditable wallet ledger (Step 12). Every balance
/// mutation goes through WalletRepository and produces one of these —
/// balances are never edited directly, so the ledger is always a complete
/// history of how the current balance was reached.
class WalletTransaction extends Equatable {
  final String id;
  final String userId;
  final CurrencyType currency;
  final TransactionDirection direction;
  final int amount;
  final String reason;
  final int balanceAfter;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.currency,
    required this.direction,
    required this.amount,
    required this.reason,
    required this.balanceAfter,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    currency,
    direction,
    amount,
    reason,
    balanceAfter,
    createdAt,
  ];
}
