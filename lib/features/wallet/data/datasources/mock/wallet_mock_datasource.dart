import '../../../../../core/errors/app_exception.dart';
import '../../../domain/entities/currency_type.dart';
import '../../../domain/entities/wallet_transaction.dart';
import '../../models/wallet_balance_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../wallet_datasource.dart';

/// MOCK DATA — replace the binding in wallet_providers.dart with a
/// datasource that calls a Cloud Function when the backend is ready. Do not
/// extend this class with production logic; in particular, a real backend
/// must re-validate every debit server-side rather than trusting the
/// client's claimed balance.
class WalletMockDatasource implements WalletDatasource {
  final Map<String, WalletBalanceModel> _balances = {};
  final Map<String, List<WalletTransactionModel>> _ledger = {};
  int _nextTransactionId = 1;

  WalletBalanceModel _balanceFor(String userId) =>
      _balances[userId] ?? const WalletBalanceModel(coins: 0, gems: 0);

  @override
  Future<WalletBalanceModel> getBalance(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _balanceFor(userId);
  }

  @override
  Future<WalletTransactionModel> credit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final current = _balanceFor(userId);
    final updated = currency == CurrencyType.coins
        ? WalletBalanceModel(coins: current.coins + amount, gems: current.gems)
        : WalletBalanceModel(coins: current.coins, gems: current.gems + amount);
    _balances[userId] = updated;

    final balanceAfter = currency == CurrencyType.coins ? updated.coins : updated.gems;
    return _appendLedgerEntry(
      userId: userId,
      currency: currency,
      direction: TransactionDirection.credit,
      amount: amount,
      reason: reason,
      balanceAfter: balanceAfter,
    );
  }

  @override
  Future<WalletTransactionModel> debit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final current = _balanceFor(userId);
    final currentAmount = currency == CurrencyType.coins ? current.coins : current.gems;

    if (currentAmount < amount) {
      final label = currency == CurrencyType.coins ? 'coins' : 'gems';
      throw ValidationException('Not enough $label.', 'insufficient-funds');
    }

    final updated = currency == CurrencyType.coins
        ? WalletBalanceModel(coins: current.coins - amount, gems: current.gems)
        : WalletBalanceModel(coins: current.coins, gems: current.gems - amount);
    _balances[userId] = updated;

    final balanceAfter = currency == CurrencyType.coins ? updated.coins : updated.gems;
    return _appendLedgerEntry(
      userId: userId,
      currency: currency,
      direction: TransactionDirection.debit,
      amount: amount,
      reason: reason,
      balanceAfter: balanceAfter,
    );
  }

  WalletTransactionModel _appendLedgerEntry({
    required String userId,
    required CurrencyType currency,
    required TransactionDirection direction,
    required int amount,
    required String reason,
    required int balanceAfter,
  }) {
    final entry = WalletTransactionModel(
      id: 'txn-${_nextTransactionId++}',
      userId: userId,
      currency: currency,
      direction: direction,
      amount: amount,
      reason: reason,
      balanceAfter: balanceAfter,
      createdAt: DateTime.now(),
    );
    _ledger.putIfAbsent(userId, () => []).add(entry);
    return entry;
  }

  @override
  Future<List<WalletTransactionModel>> getTransactionHistory(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final entries = _ledger[userId] ?? const [];
    return entries.reversed.toList();
  }
}
