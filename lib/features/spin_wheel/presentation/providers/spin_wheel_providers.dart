import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/remote/spin_wheel_remote_datasource.dart';
import '../../data/datasources/spin_wheel_datasource.dart';
import '../../data/repositories/spin_wheel_repository_impl.dart';
import '../../domain/entities/spin_result.dart';
import '../../domain/entities/spin_wheel_segment.dart';
import '../../domain/repositories/spin_wheel_repository.dart';

/// Backend binding: the server rolls the prize and pays it.
final spinWheelDatasourceProvider = Provider<SpinWheelDatasource>((ref) {
  return SpinWheelRemoteDatasource(apiClient: ref.watch(apiClientProvider));
});

final spinWheelRepositoryProvider = Provider<SpinWheelRepository>((ref) {
  return SpinWheelRepositoryImpl(ref.watch(spinWheelDatasourceProvider));
});

final spinWheelSegmentsProvider = FutureProvider<List<SpinWheelSegment>>((ref) {
  return ref.watch(spinWheelRepositoryProvider).getSegments();
});

/// State is "does the player have a spin to use" (spins are earned).
class SpinWheelController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return false;
    return ref.watch(spinWheelRepositoryProvider).isSpinAvailable(user.id);
  }

  Future<SpinResult?> spin() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return null;
    final repository = ref.read(spinWheelRepositoryProvider);
    try {
      final result = await repository.spin(user.id);
      // The prize is already credited server-side; refresh balances from it.
      ref.invalidate(walletControllerProvider);
      state = AsyncValue.data(await repository.isSpinAvailable(user.id));
      return result;
    } on AppException {
      state = AsyncValue.data(await repository.isSpinAvailable(user.id));
      return null;
    }
  }
}

final spinWheelControllerProvider =
    AsyncNotifierProvider<SpinWheelController, bool>(SpinWheelController.new);
