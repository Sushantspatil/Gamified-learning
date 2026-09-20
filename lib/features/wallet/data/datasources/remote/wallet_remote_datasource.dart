import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/network/api_client.dart';
import '../../../domain/entities/currency_type.dart';
import '../../../domain/entities/wallet_transaction.dart';
import '../../models/wallet_balance_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../wallet_datasource.dart';

class WalletRemoteDatasource implements WalletDatasource {
  final ApiClient _apiClient;

  WalletRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<WalletBalanceModel> getBalance(String userId) async {
    try {
      final data = await _apiClient.get('/wallet/balance', useApiRoot: true);
      if (data is Map<String, dynamic>) {
        return WalletBalanceModel(
          coins: data['coins'] as int? ?? 0,
          gems: data['gems'] as int? ?? 0,
        );
      }
    } catch (_) {}

    final data = await _apiClient.get('/profile', useApiRoot: true);
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid wallet response from backend.');
    }
    return WalletBalanceModel(
      coins: data['coins'] as int? ?? 0,
      gems: data['gems'] as int? ?? 0,
    );
  }

  @override
  Future<WalletTransactionModel> credit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) async {
    final currencyStr = currency == CurrencyType.coins ? 'coins' : 'gems';
    final data = await _apiClient.post(
      '/wallet/credit',
      useApiRoot: true,
      body: {
        'currency': currencyStr,
        'amount': amount,
        'reason': reason,
      },
    );

    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid credit response from backend.');
    }

    return WalletTransactionModel(
      id: data['id'] as String? ?? 'txn-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      currency: currency,
      direction: TransactionDirection.credit,
      amount: data['amount'] as int? ?? amount,
      reason: data['reason'] as String? ?? reason,
      balanceAfter: data['balance_after'] as int? ?? 0,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Future<WalletTransactionModel> debit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) async {
    final currencyStr = currency == CurrencyType.coins ? 'coins' : 'gems';
    final data = await _apiClient.post(
      '/wallet/debit',
      useApiRoot: true,
      body: {
        'currency': currencyStr,
        'amount': amount,
        'reason': reason,
      },
    );

    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid debit response from backend.');
    }

    return WalletTransactionModel(
      id: data['id'] as String? ?? 'txn-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      currency: currency,
      direction: TransactionDirection.debit,
      amount: data['amount'] as int? ?? amount,
      reason: data['reason'] as String? ?? reason,
      balanceAfter: data['balance_after'] as int? ?? 0,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Future<List<WalletTransactionModel>> getTransactionHistory(String userId) async {
    final data = await _apiClient.get('/wallet/transactions', useApiRoot: true);
    if (data is! Map<String, dynamic> || data['transactions'] is! List) {
      return const [];
    }
    final list = data['transactions'] as List;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final curr = (map['currency'] == 'gems') ? CurrencyType.gems : CurrencyType.coins;
      final dir = (map['direction'] == 'debit') ? TransactionDirection.debit : TransactionDirection.credit;
      return WalletTransactionModel(
        id: map['id'] as String? ?? '',
        userId: userId,
        currency: curr,
        direction: dir,
        amount: map['amount'] as int? ?? 0,
        reason: map['reason'] as String? ?? '',
        balanceAfter: map['balance_after'] as int? ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
    }).toList();
  }
}
