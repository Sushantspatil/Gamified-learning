import '../../domain/entities/spin_result.dart';
import '../../domain/entities/spin_wheel_segment.dart';
import '../../domain/repositories/spin_wheel_repository.dart';
import '../datasources/spin_wheel_datasource.dart';

class SpinWheelRepositoryImpl implements SpinWheelRepository {
  final SpinWheelDatasource _datasource;

  SpinWheelRepositoryImpl(this._datasource);

  @override
  Future<List<SpinWheelSegment>> getSegments() => _datasource.getSegments();

  @override
  Future<bool> isSpinAvailable(String userId) => _datasource.isSpinAvailable(userId);

  @override
  Future<SpinResult> spin(String userId) => _datasource.spin(userId);
}
