import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/mock/spin_wheel_mock_datasource.dart';
import '../../data/datasources/spin_wheel_datasource.dart';
import '../../data/repositories/spin_wheel_repository_impl.dart';
import '../../domain/entities/spin_result.dart';
import '../../domain/entities/spin_wheel_segment.dart';
import '../../domain/repositories/spin_wheel_repository.dart';

/// MOCK BINDING — swap for a Cloud-Function-backed SpinWheelDatasource
/// implementation when the backend is ready.
final spinWheelDatasourceProvider = Provider<SpinWheelDatasource>((ref) {
  return SpinWheelMockDatasource();
});

final spinWheelRepositoryProvider = Provider<SpinWheelRepository>((ref) {
  return SpinWheelRepositoryImpl(ref.watch(spinWheelDatasourceProvider));
});

final spinWheelSegmentsProvider = FutureProvider<List<SpinWheelSegment>>((ref) {
  return ref.watch(spinWheelRepositoryProvider).getSegments();
});

/// State is "is a spin available right now" (once per day).
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

    final segments = await ref.read(spinWheelSegmentsProvider.future);
    final result = await ref.read(spinWheelRepositoryProvider).spin(user.id);
    final winner = segments.firstWhere((s) => s.id == result.segmentId);

    await ref.read(walletControllerProvider.notifier).credit(
          currency: winner.currency,
          amount: winner.amount,
          reason: 'Spin wheel',
        );

    state = const AsyncValue.data(false);
    return result;
  }
}

final spinWheelControllerProvider = AsyncNotifierProvider<SpinWheelController, bool>(
  SpinWheelController.new,
);
