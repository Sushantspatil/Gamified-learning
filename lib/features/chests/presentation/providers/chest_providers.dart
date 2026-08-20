import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/chest_datasource.dart';
import '../../data/datasources/mock/chest_mock_datasource.dart';
import '../../data/repositories/chest_repository_impl.dart';
import '../../domain/entities/chest_result.dart';
import '../../domain/entities/chest_type.dart';
import '../../domain/repositories/chest_repository.dart';

/// MOCK BINDING — swap for a Firestore/Cloud-Function-backed
/// ChestDatasource implementation when the backend is ready.
final chestDatasourceProvider = Provider<ChestDatasource>((ref) {
  return ChestMockDatasource();
});

final chestRepositoryProvider = Provider<ChestRepository>((ref) {
  return ChestRepositoryImpl(ref.watch(chestDatasourceProvider));
});

/// One controller for both chest types: state is "is it available to
/// open right now" (always true for the ad chest, once-per-day for the
/// daily chest).
class ChestController extends FamilyAsyncNotifier<bool, ChestType> {
  @override
  Future<bool> build(ChestType type) async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return false;
    if (type == ChestType.ad) return true;
    return ref.watch(chestRepositoryProvider).isDailyChestAvailable(user.id);
  }

  Future<ChestResult?> open(ChestType type) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return null;

    final result = await ref.read(chestRepositoryProvider).openChest(user.id, type);
    await ref.read(walletControllerProvider.notifier).credit(
          currency: result.currency,
          amount: result.amount,
          reason: type == ChestType.daily ? 'Daily chest' : 'Ad chest',
        );

    if (type == ChestType.daily) {
      state = const AsyncValue.data(false);
    }
    return result;
  }
}

final chestControllerProvider = AsyncNotifierProvider.family<ChestController, bool, ChestType>(
  ChestController.new,
);
