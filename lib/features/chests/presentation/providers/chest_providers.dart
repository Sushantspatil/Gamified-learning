import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/chest_datasource.dart';
import '../../data/models/chest_result_model.dart';
import '../../data/repositories/chest_repository_impl.dart';
import '../../domain/entities/chest_result.dart';
import '../../domain/entities/chest_type.dart';
import '../../domain/repositories/chest_repository.dart';

/// Empty binding until the backend exposes chest rewards.
final chestDatasourceProvider = Provider<ChestDatasource>((ref) {
  return const EmptyChestDatasource();
});

class EmptyChestDatasource implements ChestDatasource {
  const EmptyChestDatasource();

  @override
  Future<bool> isDailyChestAvailable(String userId) async {
    return false;
  }

  @override
  Future<ChestResultModel> openChest(String userId, ChestType type) {
    throw UnsupportedError('Chests are not available from the backend.');
  }
}

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
    state = const AsyncValue.data(false);
    return null;
  }
}

final chestControllerProvider =
    AsyncNotifierProvider.family<ChestController, bool, ChestType>(
      ChestController.new,
    );
