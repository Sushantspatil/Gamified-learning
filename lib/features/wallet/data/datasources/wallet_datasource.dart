import '../../domain/entities/currency_type.dart';
import '../models/wallet_balance_model.dart';
import '../models/wallet_transaction_model.dart';

/// Implemented today by [WalletMockDatasource]. Swap for a datasource that
/// calls a Cloud Function once balances must be server-authoritative.
abstract class WalletDatasource {
  Future<WalletBalanceModel> getBalance(String userId);

  Future<WalletTransactionModel> credit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  });

  Future<WalletTransactionModel> debit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  });

  Future<List<WalletTransactionModel>> getTransactionHistory(String userId);
}
