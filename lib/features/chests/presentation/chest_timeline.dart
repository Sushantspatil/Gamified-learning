import 'dart:math' as math;

import 'chest_style.dart';

/// The timing of a chest opening, as plain functions of the progress `t`
/// (0 closed .. 1 fully open). Nothing here draws; [ChestOpenView] reads it.
///
/// Designed so that once the crate starts opening, it opens directly and
/// smoothly in a fluid, continuous motion rather than stepping frame by frame:
///
///   0.00 - 0.20  the chest rattles and squashes in anticipation
///   0.20         the lock snaps: bright flash, lid cracks open ("opening")
///   0.20 - 0.32  the lid swings upward smoothly, energy builds
///   0.32         the energy bursts: radiant flash, lid wide open ("burst")
///   0.32 - 0.44  continuous fluid transition to "opened"
///   0.44 - 1.00  the chest is fully opened, bathed in glowing rays and particles
///
/// Each transition is smoothed with a generous dissolve covered by the light
/// flash so the lid opening flows continuously without awkward static holds.
class ChestTimeline {
  ChestTimeline._();

  /// Where the three cuts happen.
  static const double unlock = 0.20;
  static const double burst = 0.32;
  static const double settle = 0.44;

  /// How long each cut takes, as a share of the whole opening.
  static const double dissolve = 0.07;

  static double _clamp01(double v) => v.clamp(0.0, 1.0);

  static double _smooth(double v) {
    final x = _clamp01(v);
    return x * x * (3 - 2 * x);
  }

  /// 0..1: how much of the picture that arrives at [cut] is showing at [t].
  static double cover(double t, double cut) =>
      _smooth((t - (cut - dissolve / 2)) / dissolve);

  /// The opacity of [frame] at [t]. Pictures stack in playing order, each one
  /// fading in over the one before, and each one is dropped once the next has
  /// fully covered it.
  static double opacityOf(ChestFrame frame, double t) {
    const half = dissolve / 2;
    return switch (frame) {
      ChestFrame.closed => t < unlock + half ? 1.0 : 0.0,
      ChestFrame.opening => t < burst + half ? cover(t, unlock) : 0.0,
      ChestFrame.burst => t < settle + half ? cover(t, burst) : 0.0,
      ChestFrame.opened => cover(t, settle),
    };
  }

  /// The picture that is most visible at [t].
  static ChestFrame dominantFrame(double t) {
    if (t >= settle) return ChestFrame.opened;
    if (t >= burst) return ChestFrame.burst;
    if (t >= unlock) return ChestFrame.opening;
    return ChestFrame.closed;
  }

  /// A short pulse (1 at [at], 0 well away from it).
  static double _pulse(double t, double at, double width) {
    final x = (t - at) / width;
    return math.exp(-x * x);
  }

  /// The flash of light that hides each cut: energetic flash at the unlock,
  /// peak radiant flash at the burst, and a warm settling glow. 0..1.
  static double flash(double t) => math.max(
    0.60 * _pulse(t, unlock, 0.032),
    math.max(1.0 * _pulse(t, burst, 0.045), 0.40 * _pulse(t, settle, 0.035)),
  );

  /// How hard the chest rattles, -1..1 (the sign is the direction). It builds
  /// up to the unlock, then stops dead.
  static double rattle(double t) {
    if (t <= 0 || t >= unlock) return 0;
    final build = t / unlock;
    return math.sin(t * 150) * build * build;
  }

  /// How far the chest sags before it jumps: a small squash just before the
  /// lock breaks, 0..1.
  static double squash(double t) => _pulse(t, unlock - 0.025, 0.02);

  /// The size of the chest: a punch (it jumps larger, then settles back) at
  /// each cut, the biggest at the burst.
  static double scale(double t) {
    double punch(double at, double amount, double over) {
      if (t < at) return 0;
      final x = (t - at) / over;
      if (x >= 1) return 0;
      // Fast up, slow down.
      return amount * math.sin(math.pi * math.pow(x, 0.6));
    }

    final squashed = 0.035 * squash(t);
    return 1 +
        punch(unlock, 0.05, 0.12) +
        punch(burst, 0.085, 0.18) +
        punch(settle, 0.025, 0.12) -
        squashed;
  }

  /// How high the chest rises, as a share of its height (negative is up): it
  /// lifts a little as the lid cracks, falls back at the burst.
  static double lift(double t) {
    final rise = _smooth((t - unlock) / 0.10);
    final fall = _smooth((t - burst) / 0.12);
    return -0.035 * rise * (1 - fall);
  }
}
