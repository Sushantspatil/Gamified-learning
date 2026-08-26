import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/chests/data/datasources/mock/chest_mock_datasource.dart';
import 'package:skillverse_app/features/chests/domain/entities/chest_type.dart';
import 'package:skillverse_app/features/spin_wheel/data/datasources/mock/spin_wheel_mock_datasource.dart';

void main() {
  group('ChestMockDatasource', () {
    test(
      'daily chest is available once, then blocked until it resets',
      () async {
        final datasource = ChestMockDatasource(random: Random(1));

        expect(await datasource.isDailyChestAvailable('u1'), isTrue);

        final result = await datasource.openChest('u1', ChestType.daily);
        expect(result.chestType, ChestType.daily);
        expect(result.amount, greaterThan(0));

        expect(await datasource.isDailyChestAvailable('u1'), isFalse);
        await expectLater(
          datasource.openChest('u1', ChestType.daily),
          throwsA(anything),
        );
      },
    );

    test('ad chest has no daily gate and can be opened repeatedly', () async {
      final datasource = ChestMockDatasource(random: Random(2));

      await datasource.openChest('u1', ChestType.ad);
      await datasource.openChest('u1', ChestType.ad); // does not throw
    });

    test(
      'daily and ad chests do not affect each other\'s availability',
      () async {
        final datasource = ChestMockDatasource(random: Random(3));
        await datasource.openChest('u1', ChestType.daily);
        expect(await datasource.isDailyChestAvailable('u1'), isFalse);

        // Ad chest still opens fine even though the daily chest is used up.
        await datasource.openChest('u1', ChestType.ad);
      },
    );
  });

  group('SpinWheelMockDatasource', () {
    test('segments are a fixed, non-empty catalog', () async {
      final datasource = SpinWheelMockDatasource(random: Random(1));
      final segments = await datasource.getSegments();
      expect(segments, isNotEmpty);
      expect(
        segments.map((s) => s.id).toSet().length,
        segments.length,
      ); // unique ids
    });

    test(
      'spin picks a segment id from the catalog and then blocks until reset',
      () async {
        final datasource = SpinWheelMockDatasource(random: Random(4));
        final segments = await datasource.getSegments();

        expect(await datasource.isSpinAvailable('u1'), isTrue);
        final result = await datasource.spin('u1');
        expect(segments.map((s) => s.id), contains(result.segmentId));

        expect(await datasource.isSpinAvailable('u1'), isFalse);
        await expectLater(datasource.spin('u1'), throwsA(anything));
      },
    );
  });
}
