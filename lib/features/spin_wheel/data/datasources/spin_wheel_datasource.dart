import '../models/spin_result_model.dart';
import '../models/spin_wheel_segment_model.dart';

/// Implemented today by [SpinWheelMockDatasource]. Swap for a
/// Cloud-Function-backed implementation once spin results must be
/// server-authoritative (Step 10) — the outcome is decided only here,
/// never in the UI.
abstract class SpinWheelDatasource {
  Future<List<SpinWheelSegmentModel>> getSegments();

  Future<bool> isSpinAvailable(String userId);

  Future<SpinResultModel> spin(String userId);
}
