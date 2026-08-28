import '../../domain/entities/currency_type.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_datasource.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletDatasource _datasource;

  WalletRepositoryImpl(this._datasource);

  @override
  Future<WalletBalance> getBalance(String userId) =>
      _datasource.getBalance(userId);

  @override
  Future<WalletTransaction> credit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) {
    return _datasource.credit(
      userId: userId,
      currency: currency,
      amount: amount,
      reason: reason,
    );
  }

  @override
  Future<WalletTransaction> debit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) {
    return _datasource.debit(
      userId: userId,
      currency: currency,
      amount: amount,
      reason: reason,
    );
  }

  @override
  Future<List<WalletTransaction>> getTransactionHistory(String userId) {
    return _datasource.getTransactionHistory(userId);
  }
}
