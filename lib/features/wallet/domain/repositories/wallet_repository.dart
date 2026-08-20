import '../entities/currency_type.dart';
import '../entities/wallet_balance.dart';
import '../entities/wallet_transaction.dart';

/// The sole authority for coin/gem balances. No other feature may mutate a
/// balance directly — every change goes through credit/debit here and
/// produces a ledger entry. Once a backend exists, this becomes a request a
/// Cloud Function validates and executes server-side (Step 10) — the
/// client is never the source of truth for its own balance.
abstract class WalletRepository {
  Future<WalletBalance> getBalance(String userId);

  Future<WalletTransaction> credit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  });

  /// Throws a ValidationException if the balance is insufficient.
  Future<WalletTransaction> debit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  });

  Future<List<WalletTransaction>> getTransactionHistory(String userId);
}
