import '../entities/spin_result.dart';
import '../entities/spin_wheel_segment.dart';

abstract class SpinWheelRepository {
  /// The wheel's fixed layout — public information, safe for the client to
  /// render.
  Future<List<SpinWheelSegment>> getSegments();

  Future<bool> isSpinAvailable(String userId);

  /// Throws a ValidationException if a spin is used before it resets.
  Future<SpinResult> spin(String userId);
}
