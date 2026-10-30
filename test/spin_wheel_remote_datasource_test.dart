import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/spin_wheel/data/datasources/remote/spin_wheel_remote_datasource.dart';
import 'package:skillverse_app/features/wallet/domain/entities/currency_type.dart';

Future<SpinWheelRemoteDatasource> _datasource(
  Future<http.Response> Function(http.Request) handler,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  return SpinWheelRemoteDatasource(
    apiClient: ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test/api/v1'),
      storage: storage,
      httpClient: MockClient(handler),
    ),
  );
}

http.Response _json(Object data, [int status = 200]) =>
    http.Response(jsonEncode({'success': status < 300, 'data': data}), status);

void main() {
  test('segments are ordered by sort_order and map currency', () async {
    final ds = await _datasource((_) async {
      return _json([
        {'segment_code': 'b', 'currency': 'gems', 'amount': 5, 'sort_order': 2},
        {
          'segment_code': 'a',
          'currency': 'coins',
          'amount': 10,
          'sort_order': 1,
        },
      ]);
    });
    final segments = await ds.getSegments();
    expect(segments.map((s) => s.id), ['a', 'b']);
    expect(segments.last.currency, CurrencyType.gems);
  });

  test('isSpinAvailable is true only when the player has spins', () async {
    var spins = 0;
    final ds = await _datasource((_) async => _json({'spins': spins}));
    expect(await ds.isSpinAvailable('u'), isFalse);
    spins = 2;
    expect(await ds.isSpinAvailable('u'), isTrue);
  });

  test('spin sends a UUID Idempotency-Key and returns the segment', () async {
    String? key;
    final ds = await _datasource((request) async {
      key = request.headers['Idempotency-Key'];
      return _json({'segment_code': 'jackpot'});
    });
    final result = await ds.spin('u');
    expect(result.segmentId, 'jackpot');
    expect(
      key,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test(
    'a network failure keeps the key so the retry cannot double-spend',
    () async {
      final keys = <String?>[];
      var attempt = 0;
      final ds = await _datasource((request) async {
        keys.add(request.headers['Idempotency-Key']);
        if (++attempt == 1) throw const SocketException('offline');
        return _json({'segment_code': 'coins-10'});
      });

      await expectLater(ds.spin('u'), throwsA(isA<NetworkException>()));
      await ds.spin('u'); // retry
      await ds.spin('u'); // a fresh tap after success gets a new key

      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[0]));
    },
  );

  test(
    'no spins left (409) is a ValidationException and drops the key',
    () async {
      final keys = <String?>[];
      final ds = await _datasource((request) async {
        keys.add(request.headers['Idempotency-Key']);
        return http.Response(
          jsonEncode({'success': false, 'message': 'no spins available'}),
          409,
        );
      });
      await expectLater(ds.spin('u'), throwsA(isA<ValidationException>()));
      await expectLater(ds.spin('u'), throwsA(isA<ValidationException>()));
      expect(keys[0], isNot(keys[1]));
    },
  );
}
