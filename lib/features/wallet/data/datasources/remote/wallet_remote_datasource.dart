import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/network/api_client.dart';
import '../../../domain/entities/currency_type.dart';
import '../../models/wallet_balance_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../wallet_datasource.dart';

class WalletRemoteDatasource implements WalletDatasource {
  final ApiClient _apiClient;

  WalletRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<WalletBalanceModel> getBalance(String userId) async {
    final data = await _apiClient.get('/profile');
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
  }) {
    throw const ServerException(
      'The backend does not provide a wallet credit endpoint yet.',
      'wallet-credit-unsupported',
    );
  }

  @override
  Future<WalletTransactionModel> debit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) {
    throw const ServerException(
      'The backend does not provide a wallet debit endpoint yet.',
      'wallet-debit-unsupported',
    );
  }

  @override
  Future<List<WalletTransactionModel>> getTransactionHistory(String userId) {
    throw const ServerException(
      'The backend does not provide wallet transaction history yet.',
      'wallet-history-unsupported',
    );
  }
}
