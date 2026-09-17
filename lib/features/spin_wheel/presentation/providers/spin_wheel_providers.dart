import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/spin_wheel_datasource.dart';
import '../../data/models/spin_result_model.dart';
import '../../data/models/spin_wheel_segment_model.dart';
import '../../data/repositories/spin_wheel_repository_impl.dart';
import '../../domain/entities/spin_result.dart';
import '../../domain/entities/spin_wheel_segment.dart';
import '../../domain/repositories/spin_wheel_repository.dart';

/// Empty binding until the backend exposes spin wheel rewards.
final spinWheelDatasourceProvider = Provider<SpinWheelDatasource>((ref) {
  return const EmptySpinWheelDatasource();
});

class EmptySpinWheelDatasource implements SpinWheelDatasource {
  const EmptySpinWheelDatasource();

  @override
  Future<List<SpinWheelSegmentModel>> getSegments() async {
    return const [];
  }

  @override
  Future<bool> isSpinAvailable(String userId) async {
    return false;
  }

  @override
  Future<SpinResultModel> spin(String userId) {
    throw UnsupportedError('Spin wheel is not available from the backend.');
  }
}

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
    state = const AsyncValue.data(false);
    return null;
  }
}

final spinWheelControllerProvider =
    AsyncNotifierProvider<SpinWheelController, bool>(SpinWheelController.new);
