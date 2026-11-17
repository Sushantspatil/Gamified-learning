import 'dart:math' as math;

import 'chest_style.dart';

/// The timing of a chest opening, as plain functions of the progress `t`
/// (0 closed .. 1 fully open). Nothing here draws; [ChestOpenView] reads it.
///
/// A chest has four pictures (closed, opening, burst, opened) and no pictures in
/// between, so the opening is a short film cut in three places:
///
///   0.00 - 0.20  the chest rattles harder and harder (the lock is giving way)
///   0.20         the lock breaks: a flash, cut to "opening"
///   0.20 - 0.42  the lid is cracked, light leaks out, the chest rises
///   0.42         the energy bursts: a bigger flash, cut to "burst"
///   0.42 - 0.70  the burst, the chest pops and settles
///   0.70         cut to "opened", the final resting picture
///
/// Each cut is a very short dissolve (about 90 ms of a 2.6 s opening) hidden
/// by the flash. The incoming picture fades in *over* the outgoing one, which
/// stays fully opaque until it is covered, so the chest never turns see-through
/// halfway between two pictures.
class ChestTimeline {
  ChestTimeline._();

  /// Where the three cuts happen.
  static const double unlock = 0.20;
  static const double burst = 0.42;
  static const double settle = 0.70;

  /// How long each cut takes, as a share of the whole opening.
  static const double dissolve = 0.035;

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

  /// The flash of light that hides each cut: small when the lock breaks, large
  /// when the energy bursts, a soft one as the chest settles. 0..1.
  static double flash(double t) => math.max(
    0.55 * _pulse(t, unlock, 0.028),
    math.max(1.0 * _pulse(t, burst, 0.035), 0.35 * _pulse(t, settle, 0.03)),
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
        punch(unlock, 0.045, 0.14) +
        punch(burst, 0.085, 0.24) +
        punch(settle, 0.02, 0.12) -
        squashed;
  }

  /// How high the chest rises, as a share of its height (negative is up): it
  /// lifts a little as the lid cracks, falls back at the burst.
  static double lift(double t) {
    final rise = _smooth((t - unlock) / 0.12);
    final fall = _smooth((t - burst) / 0.12);
    return -0.03 * rise * (1 - fall);
  }
}
