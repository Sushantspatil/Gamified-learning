import 'dart:math';

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/utils/date_key.dart';
import '../../../../wallet/domain/entities/currency_type.dart';
import '../../models/spin_result_model.dart';
import '../../models/spin_wheel_segment_model.dart';
import '../spin_wheel_datasource.dart';

/// Placeholder wheel layout — not specified by the product requirements.
const List<SpinWheelSegmentModel> _segments = [
  SpinWheelSegmentModel(id: 's1', currency: CurrencyType.coins, amount: 10),
  SpinWheelSegmentModel(id: 's2', currency: CurrencyType.coins, amount: 20),
  SpinWheelSegmentModel(id: 's3', currency: CurrencyType.gems, amount: 5),
  SpinWheelSegmentModel(id: 's4', currency: CurrencyType.coins, amount: 50),
  SpinWheelSegmentModel(id: 's5', currency: CurrencyType.gems, amount: 10),
  SpinWheelSegmentModel(id: 's6', currency: CurrencyType.coins, amount: 100),
];

/// MOCK DATA — this is the only place the winning segment is decided.
/// Replace the binding in spin_wheel_providers.dart with a datasource that
/// calls a Cloud Function once results must be server-authoritative;
/// nothing above this layer (controller, widgets) needs to change when
/// that happens.
class SpinWheelMockDatasource implements SpinWheelDatasource {
  final Map<String, String> _lastSpinDateKeyByUser = {};
  final Random _random;

  SpinWheelMockDatasource({Random? random}) : _random = random ?? Random();

  @override
  Future<List<SpinWheelSegmentModel>> getSegments() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _segments;
  }

  @override
  Future<bool> isSpinAvailable(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final today = dateKey(DateTime.now());
    return _lastSpinDateKeyByUser[userId] != today;
  }

  @override
  Future<SpinResultModel> spin(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final today = dateKey(DateTime.now());
    if (_lastSpinDateKeyByUser[userId] == today) {
      throw const ValidationException("Today's spin has already been used.", 'already-spun');
    }
    _lastSpinDateKeyByUser[userId] = today;

    final winner = _segments[_random.nextInt(_segments.length)];
    return SpinResultModel(segmentId: winner.id);
  }
}
