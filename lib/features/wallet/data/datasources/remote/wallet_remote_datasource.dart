import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/network/dtos/wallet_dtos.dart';
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
    final data = await _apiClient.get(ApiEndpoints.walletBalance);
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid wallet response from backend.');
    }
    final dto = WalletBalanceResponseDto.fromJson(data);
    return WalletBalanceModel(
      coins: dto.coins,
      gems: dto.gems,
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
    final requestDto = WalletCreditRequestDto(
      currency: currencyStr,
      amount: amount,
      reason: reason,
    );
    final data = await _apiClient.post(
      ApiEndpoints.walletCredit,
      body: requestDto.toJson(),
    );

    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid credit response from backend.');
    }

    final dto = WalletTransactionResponseDto.fromJson(data);
    return WalletTransactionModel(
      id: dto.id.isNotEmpty ? dto.id : 'txn-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      currency: currency,
      direction: TransactionDirection.credit,
      amount: dto.amount > 0 ? dto.amount : amount,
      reason: dto.reason.isNotEmpty ? dto.reason : reason,
      balanceAfter: dto.balanceAfter,
      createdAt: dto.createdAt,
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
    final requestDto = WalletDebitRequestDto(
      currency: currencyStr,
      amount: amount,
      reason: reason,
    );
    final data = await _apiClient.post(
      ApiEndpoints.walletDebit,
      body: requestDto.toJson(),
    );

    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid debit response from backend.');
    }

    final dto = WalletTransactionResponseDto.fromJson(data);
    return WalletTransactionModel(
      id: dto.id.isNotEmpty ? dto.id : 'txn-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      currency: currency,
      direction: TransactionDirection.debit,
      amount: dto.amount > 0 ? dto.amount : amount,
      reason: dto.reason.isNotEmpty ? dto.reason : reason,
      balanceAfter: dto.balanceAfter,
      createdAt: dto.createdAt,
    );
  }

  @override
  Future<List<WalletTransactionModel>> getTransactionHistory(String userId) async {
    final data = await _apiClient.get(ApiEndpoints.walletTransactions);
    if (data is! Map<String, dynamic>) {
      return const [];
    }
    final historyDto = WalletHistoryResponseDto.fromJson(data);
    return historyDto.transactions.map((tx) {
      final curr = (tx.currency == 'gems') ? CurrencyType.gems : CurrencyType.coins;
      final dir = (tx.direction == 'debit') ? TransactionDirection.debit : TransactionDirection.credit;
      return WalletTransactionModel(
        id: tx.id,
        userId: userId,
        currency: curr,
        direction: dir,
        amount: tx.amount,
        reason: tx.reason,
        balanceAfter: tx.balanceAfter,
        createdAt: tx.createdAt,
      );
    }).toList();
  }
}
