import '../../domain/entities/wallet_transaction.dart';

class WalletTransactionModel extends WalletTransaction {
  const WalletTransactionModel({
    required super.id,
    required super.userId,
    required super.currency,
    required super.direction,
    required super.amount,
    required super.reason,
    required super.balanceAfter,
    required super.createdAt,
  });
}
