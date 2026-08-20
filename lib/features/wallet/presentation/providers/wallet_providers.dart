import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/mock/wallet_mock_datasource.dart';
import '../../data/datasources/wallet_datasource.dart';
import '../../data/repositories/wallet_repository_impl.dart';
import '../../domain/entities/currency_type.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';

/// MOCK BINDING — swap for a datasource that calls a Cloud Function when
/// the backend is ready.
final walletDatasourceProvider = Provider<WalletDatasource>((ref) {
  return WalletMockDatasource();
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepositoryImpl(ref.watch(walletDatasourceProvider));
});

class WalletController extends AsyncNotifier<WalletBalance> {
  @override
  Future<WalletBalance> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return WalletBalance.zero;
    return ref.watch(walletRepositoryProvider).getBalance(user.id);
  }

  Future<void> credit({required CurrencyType currency, required int amount, required String reason}) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue<WalletBalance>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await ref.read(walletRepositoryProvider).credit(
            userId: user.id,
            currency: currency,
            amount: amount,
            reason: reason,
          );
      return ref.read(walletRepositoryProvider).getBalance(user.id);
    });
  }

  /// Returns false (and leaves state/balance untouched) if the debit was
  /// rejected for insufficient funds, so callers (e.g. the shop) can show
  /// an error without needing to parse exception types themselves.
  Future<bool> debit({required CurrencyType currency, required int amount, required String reason}) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;

    try {
      await ref
          .read(walletRepositoryProvider)
          .debit(userId: user.id, currency: currency, amount: amount, reason: reason);
    } catch (_) {
      return false;
    }

    state = const AsyncValue<WalletBalance>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(walletRepositoryProvider).getBalance(user.id));
    return true;
  }
}

final walletControllerProvider = AsyncNotifierProvider<WalletController, WalletBalance>(
  WalletController.new,
);

final transactionHistoryProvider = FutureProvider<List<WalletTransaction>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return const [];
  // Re-fetch whenever the balance changes so history stays in sync.
  ref.watch(walletControllerProvider);
  return ref.watch(walletRepositoryProvider).getTransactionHistory(user.id);
});
