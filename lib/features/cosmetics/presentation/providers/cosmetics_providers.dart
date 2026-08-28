import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/cosmetics_datasource.dart';
import '../../data/datasources/mock/cosmetics_mock_datasource.dart';
import '../../data/repositories/cosmetics_repository_impl.dart';
import '../../domain/entities/cosmetic_item.dart';
import '../../domain/repositories/cosmetics_repository.dart';

enum CosmeticPurchaseResult { success, insufficientFunds }

class CosmeticsState {
  final List<CosmeticItem> catalog;
  final Set<String> ownedIds;
  final String? equippedId;

  const CosmeticsState({
    required this.catalog,
    required this.ownedIds,
    required this.equippedId,
  });
}

/// MOCK BINDING — swap for a Firestore-backed CosmeticsDatasource
/// implementation when the backend is ready.
final cosmeticsDatasourceProvider = Provider<CosmeticsDatasource>((ref) {
  return CosmeticsMockDatasource();
});

final cosmeticsRepositoryProvider = Provider<CosmeticsRepository>((ref) {
  return CosmeticsRepositoryImpl(ref.watch(cosmeticsDatasourceProvider));
});

class CosmeticsController extends AsyncNotifier<CosmeticsState> {
  @override
  Future<CosmeticsState> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final repository = ref.watch(cosmeticsRepositoryProvider);
    final catalog = await repository.getCatalog();

    if (user == null) {
      return CosmeticsState(
        catalog: catalog,
        ownedIds: const {},
        equippedId: null,
      );
    }

    final owned = await repository.getOwnedCosmeticIds(user.id);
    final equipped = await repository.getEquippedCosmeticId(user.id);
    return CosmeticsState(
      catalog: catalog,
      ownedIds: owned,
      equippedId: equipped,
    );
  }

  Future<CosmeticPurchaseResult> purchase(CosmeticItem item) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return CosmeticPurchaseResult.insufficientFunds;

    final succeeded = await ref
        .read(walletControllerProvider.notifier)
        .debit(
          currency: CurrencyType.coins,
          amount: item.costCoins,
          reason: 'Cosmetic: ${item.name}',
        );
    if (!succeeded) return CosmeticPurchaseResult.insufficientFunds;

    await ref
        .read(cosmeticsRepositoryProvider)
        .recordPurchase(user.id, item.id);
    ref.invalidateSelf();
    await future;
    return CosmeticPurchaseResult.success;
  }

  Future<void> equip(String cosmeticId) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    await ref
        .read(cosmeticsRepositoryProvider)
        .setEquipped(user.id, cosmeticId);
    ref.invalidateSelf();
    await future;
  }
}

final cosmeticsControllerProvider =
    AsyncNotifierProvider<CosmeticsController, CosmeticsState>(
      CosmeticsController.new,
    );
