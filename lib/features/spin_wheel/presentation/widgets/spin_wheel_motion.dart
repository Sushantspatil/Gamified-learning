import 'dart:math' as math;

import 'package:flutter/animation.dart';

const double _tau = 2 * math.pi;

/// The wheel's whole spin as one animation, so it moves like a real one:
///
///  1. a small pull backwards (the wind-up),
///  2. a quick pick-up to full speed,
///  3. a long, slowing run that creeps over the last pegs,
///  4. a tiny overshoot past the stop point and a settle back onto it.
///
/// It always ends exactly on [end] (the angle that puts the chosen prize under
/// the pointer); the shape only changes how it gets there.
class WheelSpinAnimatable extends Animatable<double> {
  final double begin;
  final double end;

  /// Radians turned backwards before the spin starts.
  final double pullBack;

  /// Radians past [end] before settling back. Keep it well inside a segment.
  final double overshoot;

  static const double _windUpEnd = 0.05;
  static const double _settleStart = 0.92;

  /// Slow start, fast middle, very long tail.
  static const Curve _run = Cubic(0.25, 0.0, 0.05, 1.0);

  const WheelSpinAnimatable({
    required this.begin,
    required this.end,
    this.pullBack = 0.16,
    this.overshoot = 0.05,
  });

  @override
  double transform(double t) {
    final x = t.clamp(0.0, 1.0);
    if (x < _windUpEnd) {
      return begin - pullBack * Curves.easeOut.transform(x / _windUpEnd);
    }
    final from = begin - pullBack;
    final peak = end + overshoot;
    if (x < _settleStart) {
      final u = (x - _windUpEnd) / (_settleStart - _windUpEnd);
      return from + (peak - from) * _run.transform(u);
    }
    final u = (x - _settleStart) / (1 - _settleStart);
    if (u >= 1) return end;
    return peak + (end - peak) * Curves.easeInOut.transform(u);
  }
}

/// How far the pointer's flapper is pushed by the pegs, for a wheel turned by
/// [angle]: -1 is fully pushed (a peg is right under it), 0 is at rest, and a
/// small positive value is the little rebound after a peg slips past.
///
/// Pure, so it can be tested without drawing anything.
double wheelPointerDeflection(double angle, int segmentCount) {
  final sweep = _tau / segmentCount;
  final onWheel = ((-angle) % _tau + _tau) % _tau;
  final phase = (onWheel / sweep) % 1.0;
  // How far the wheel has carried the pointer towards the next peg: 0..1.
  final x = 1 - phase;
  if (x >= 0.72) {
    final u = ((x - 0.72) / 0.28).clamp(0.0, 1.0);
    return -(u * u * (3 - 2 * u)); // a peg pushes the flapper along
  }
  if (x <= 0.30) {
    final v = x / 0.30; // the peg has slipped past: it springs back
    return -(1 - v) * math.cos(v * math.pi);
  }
  return 0;
}

/// "Next spin in 5h 23m" for the time left until the free spin comes back.
String nextSpinLabel(Duration remaining) {
  if (remaining <= Duration.zero) return 'Ready to spin';
  final minutes = (remaining.inSeconds + 59) ~/ 60; // round up
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return 'Next spin in ${m}m';
  if (m == 0) return 'Next spin in ${h}h';
  return 'Next spin in ${h}h ${m}m';
}

/// Turns a looping 0..1 animation into seconds that keep adding up, and lets
/// the speed change from moment to moment (faster while the wheel spins)
/// without the picture ever jumping, which a plain "value times speed" would.
class SpinClock {
  /// How long one loop of the ambient animation lasts.
  static const double ambientSeconds = 30;

  double? _last;
  double _seconds = 0;

  /// [phase] is the loop's current 0..1 value; [speed] 1 is normal.
  double advance(double phase, double periodSeconds, double speed) {
    final last = _last;
    _last = phase;
    if (last == null) return _seconds;
    var d = phase - last;
    if (d < -0.5) d += 1; // the loop wrapped round
    if (d < 0) d = 0;
    _seconds += d * periodSeconds * speed;
    return _seconds;
  }
}
