import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/widgets/spin_wheel_motion.dart';
import 'package:skillverse_app/features/spin_wheel/presentation/widgets/spin_wheel_painter.dart';

void main() {
  group('WheelSpinAnimatable', () {
    const spin = WheelSpinAnimatable(begin: 1.0, end: 45.0);

    test('pulls back first, then runs, and ends exactly on the target', () {
      expect(spin.transform(0), 1.0);
      expect(spin.transform(0.04), lessThan(1.0)); // the wind-up
      expect(spin.transform(0.3), greaterThan(10)); // running
      expect(spin.transform(1.0), 45.0);
    });

    test('goes a little past the target, then settles back onto it', () {
      var peak = 0.0;
      for (var i = 0; i <= 1000; i++) {
        peak = math.max(peak, spin.transform(i / 1000));
      }
      expect(peak, greaterThan(45.0));
      expect(peak, lessThan(45.1)); // stays well inside a segment
    });

    test('slows right down at the end (long, creeping tail)', () {
      final nearEnd = spin.transform(0.85);
      final atEnd = spin.transform(1.0);
      // The last 15% of the time covers well under 3% of the whole turn.
      expect((atEnd - nearEnd).abs(), lessThan(0.03 * 44));
    });

    test('keeps the landing inside the chosen prize', () {
      final target = wheelTargetAngle(
        index: 4,
        segmentCount: 10,
        currentAngle: -0.3,
        turns: 6,
        offsetFraction: 0.3,
      );
      final animation = WheelSpinAnimatable(begin: -0.3, end: target);
      expect(segmentIndexAtPointer(animation.transform(1.0), 10), 4);
    });
  });

  group('wheelPointerDeflection', () {
    test('rests straight in the middle of a prize', () {
      for (var i = 0; i < 10; i++) {
        expect(wheelPointerDeflection(wheelRestAngle(i, 10), 10), 0);
      }
    });

    test('is pushed hard when a peg is right under it', () {
      // The wheel angle that puts a divider exactly under the pointer.
      final onPeg = -2 * math.pi / 10 * 3;
      expect(wheelPointerDeflection(onPeg, 10), closeTo(-1, 1e-9));
    });

    test('springs back with a small rebound after the peg passes', () {
      final past = -2 * math.pi / 10 * 3 + 0.5 * (2 * math.pi / 10) * 0.3;
      // A little past a divider: still moving back towards rest.
      expect(wheelPointerDeflection(past, 10).abs(), lessThan(1));
      var rebound = 0.0;
      for (var i = 0; i < 1000; i++) {
        rebound = math.max(
          rebound,
          wheelPointerDeflection(-i / 1000 * 2 * math.pi / 10, 10),
        );
      }
      expect(rebound, greaterThan(0));
      expect(rebound, lessThan(0.3));
    });
  });

  group('nextSpinLabel', () {
    test('counts down in hours and minutes', () {
      expect(
        nextSpinLabel(const Duration(hours: 5, minutes: 23)),
        'Next spin in 5h 23m',
      );
      expect(nextSpinLabel(const Duration(hours: 2)), 'Next spin in 2h');
      expect(nextSpinLabel(const Duration(minutes: 7)), 'Next spin in 7m');
      expect(nextSpinLabel(const Duration(seconds: 20)), 'Next spin in 1m');
      expect(nextSpinLabel(Duration.zero), 'Ready to spin');
    });
  });
}
