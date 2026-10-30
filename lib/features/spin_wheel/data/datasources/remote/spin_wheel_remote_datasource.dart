import 'dart:math';

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../wallet/domain/entities/currency_type.dart';
import '../../models/spin_result_model.dart';
import '../../models/spin_wheel_segment_model.dart';
import '../spin_wheel_datasource.dart';

/// Server-authoritative wheel: the backend rolls the prize and credits it.
/// The client only receives the winning `segment_code` to animate to.
class SpinWheelRemoteDatasource implements SpinWheelDatasource {
  final ApiClient _apiClient;
  final Random _random;

  /// Idempotency key of a spin whose outcome is still unknown (e.g. the
  /// request timed out). The next tap reuses it, so the server returns the
  /// first result instead of spending another spin.
  String? _pendingKey;

  SpinWheelRemoteDatasource({required ApiClient apiClient, Random? random})
    : _apiClient = apiClient,
      _random = random ?? Random.secure();

  @override
  Future<List<SpinWheelSegmentModel>> getSegments() async {
    final data = await _apiClient.get(ApiEndpoints.spinWheelSegments);
    if (data is! List) {
      throw const ServerException('Invalid spin wheel response from backend.');
    }
    final segments = data.whereType<Map<String, dynamic>>().toList()
      ..sort(
        (a, b) => (a['sort_order'] as num? ?? 0).compareTo(
          b['sort_order'] as num? ?? 0,
        ),
      );
    return [
      for (final s in segments)
        SpinWheelSegmentModel(
          id: s['segment_code'] as String,
          currency: s['currency'] == 'gems'
              ? CurrencyType.gems
              : CurrencyType.coins,
          amount: (s['amount'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<bool> isSpinAvailable(String userId) async {
    final data = await _apiClient.get(ApiEndpoints.spinWheelStatus);
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid spin status response from backend.');
    }
    return ((data['spins'] as num?) ?? 0) > 0;
  }

  @override
  Future<SpinResultModel> spin(String userId) async {
    final key = _pendingKey ??= _newIdempotencyKey();
    try {
      final data = await _apiClient.post(
        ApiEndpoints.spinWheelSpin,
        headers: {'Idempotency-Key': key},
      );
      _pendingKey = null;
      if (data is! Map<String, dynamic>) {
        throw const ServerException('Invalid spin response from backend.');
      }
      return SpinResultModel(segmentId: data['segment_code'] as String);
    } on NetworkException {
      rethrow; // outcome unknown: keep the key so a retry cannot double-spend
    } catch (_) {
      _pendingKey = null; // definitive answer (e.g. no spins left)
      rethrow;
    }
  }

  String _newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
