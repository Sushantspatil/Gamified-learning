import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/chests/presentation/chest_style.dart';
import 'package:skillverse_app/features/chests/presentation/chest_timeline.dart';

void main() {
  const steps = 1000;
  final times = [for (var i = 0; i <= steps; i++) i / steps];

  group('which picture shows', () {
    test('the chest starts closed and ends opened', () {
      expect(ChestTimeline.opacityOf(ChestFrame.closed, 0), 1);
      for (final f in [
        ChestFrame.opening,
        ChestFrame.burst,
        ChestFrame.opened,
      ]) {
        expect(ChestTimeline.opacityOf(f, 0), 0);
      }
      expect(ChestTimeline.opacityOf(ChestFrame.opened, 1), 1);
      for (final f in [
        ChestFrame.closed,
        ChestFrame.opening,
        ChestFrame.burst,
      ]) {
        expect(ChestTimeline.opacityOf(f, 1), 0);
      }
    });

    test('the chest is never see-through, even in the middle of a cut', () {
      // The pictures are stacked, each fading in over the one before. What is
      // seen is all of them composited: it must be fully opaque at every moment
      // (the old cross-fade dipped to about 75% and looked like a ghost).
      for (final t in times) {
        var seeThrough = 1.0;
        for (final f in ChestFrame.values) {
          seeThrough *= 1 - ChestTimeline.opacityOf(f, t);
        }
        expect(1 - seeThrough, closeTo(1, 1e-9), reason: 'at t=$t');
      }
    });

    test('between the cuts exactly one picture shows', () {
      for (final entry in {
        0.05: ChestFrame.closed,
        0.26: ChestFrame.opening,
        0.38: ChestFrame.burst,
        0.80: ChestFrame.opened,
      }.entries) {
        for (final f in ChestFrame.values) {
          expect(
            ChestTimeline.opacityOf(f, entry.key),
            f == entry.value ? 1 : 0,
            reason: '$f at ${entry.key}',
          );
        }
      }
    });

    test('a cut is quick: it is over within the dissolve width', () {
      const half = ChestTimeline.dissolve / 2;
      expect(
        ChestTimeline.cover(ChestTimeline.unlock - half, ChestTimeline.unlock),
        0,
      );
      expect(
        ChestTimeline.cover(ChestTimeline.unlock, ChestTimeline.unlock),
        closeTo(0.5, 1e-9),
      );
      expect(
        ChestTimeline.cover(ChestTimeline.unlock + half, ChestTimeline.unlock),
        1,
      );
    });

    test('the pictures come in the order of the story', () {
      var last = -1;
      for (final t in times) {
        final index = ChestTimeline.dominantFrame(t).index;
        expect(index, greaterThanOrEqualTo(last));
        last = index;
      }
      expect(ChestTimeline.dominantFrame(0), ChestFrame.closed);
      expect(ChestTimeline.dominantFrame(0.26), ChestFrame.opening);
      expect(ChestTimeline.dominantFrame(0.38), ChestFrame.burst);
      expect(ChestTimeline.dominantFrame(0.80), ChestFrame.opened);
    });
  });

  group('the flash that hides each cut', () {
    test('peaks at the cuts, the burst the brightest, and is dark between', () {
      final unlock = ChestTimeline.flash(ChestTimeline.unlock);
      final burst = ChestTimeline.flash(ChestTimeline.burst);
      expect(unlock, greaterThan(0.4));
      expect(burst, greaterThan(unlock));
      expect(burst, closeTo(1, 0.02));
      expect(ChestTimeline.flash(0.05), lessThan(0.01));
      expect(ChestTimeline.flash(0.80), lessThan(0.01));
    });

    test('stays within 0..1 all the way through', () {
      for (final t in times) {
        expect(ChestTimeline.flash(t), inInclusiveRange(0, 1));
      }
    });
  });

  group('the motion', () {
    test('the rattle builds up and stops dead at the unlock', () {
      double strongest(double from, double to) {
        var best = 0.0;
        for (final t in times) {
          if (t < from || t >= to) continue;
          best = ChestTimeline.rattle(t).abs() > best
              ? ChestTimeline.rattle(t).abs()
              : best;
        }
        return best;
      }

      expect(strongest(0.0, 0.07), lessThan(strongest(0.13, 0.2)));
      expect(ChestTimeline.rattle(0), 0);
      expect(ChestTimeline.rattle(ChestTimeline.unlock), 0);
      expect(ChestTimeline.rattle(0.5), 0);
      for (final t in times) {
        expect(ChestTimeline.rattle(t).abs(), lessThanOrEqualTo(1));
      }
    });

    test('the chest is its normal size at the start and the end', () {
      expect(ChestTimeline.scale(0), closeTo(1, 1e-9));
      expect(ChestTimeline.scale(1), closeTo(1, 1e-9));
    });

    test(
      'the chest pops at the cuts, most at the burst, and never shrinks much',
      () {
        var atUnlock = 1.0, atBurst = 1.0, smallest = 1.0;
        for (final t in times) {
          final s = ChestTimeline.scale(t);
          if (t >= 0.18 && t < 0.28) atUnlock = s > atUnlock ? s : atUnlock;
          if (t >= 0.28 && t < 0.44) atBurst = s > atBurst ? s : atBurst;
          smallest = s < smallest ? s : smallest;
        }
        expect(atUnlock, greaterThan(1.02));
        expect(atBurst, greaterThan(atUnlock));
        expect(atBurst, lessThan(1.12));
        expect(smallest, greaterThan(0.95));
      },
    );

    test('the chest rises as the lid cracks, then comes back down', () {
      expect(ChestTimeline.lift(0), 0);
      expect(ChestTimeline.lift(0.26), lessThan(0)); // negative is up
      expect(ChestTimeline.lift(0.26), greaterThan(-0.05));
      expect(ChestTimeline.lift(1), closeTo(0, 1e-9));
    });
  });
}
