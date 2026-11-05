import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'spin_wheel_motion.dart';

/// The winning prize flashing when the wheel stops: the segment under the
/// pointer pulses white and gold for a moment. Static position (the wheel is
/// at rest by then), driven by [progress] from 0 to 1.
class WheelWinFlashPainter extends CustomPainter {
  final Animation<double> progress;

  /// The wheel's final rotation, and the prize that ended under the pointer.
  final double angle;
  final int index;
  final int segmentCount;

  WheelWinFlashPainter({
    required this.progress,
    required this.angle,
    required this.index,
    required this.segmentCount,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    if (p <= 0 || p >= 0.8) return;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final face = Rect.fromCircle(center: c, radius: r * 0.8);
    final sweep = 2 * math.pi / segmentCount;
    final start = index * sweep + angle - math.pi / 2;

    // Three quick pulses that fade away.
    final fade = 1 - p / 0.8;
    final pulse = 0.5 - 0.5 * math.cos(p / 0.8 * math.pi * 6);
    final alpha = (0.62 * pulse * fade).clamp(0.0, 1.0);

    canvas.drawArc(
      face,
      start,
      sweep,
      true,
      Paint()..color = Color.fromRGBO(255, 250, 220, alpha),
    );
    canvas.drawArc(
      face,
      start,
      sweep,
      true,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02
        ..color = Color.fromRGBO(255, 214, 90, (0.9 * fade).clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(covariant WheelWinFlashPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.angle != angle ||
      oldDelegate.index != index;
}

/// Coins that fly from the wheel up to the coin counter, and a ring that
/// pulses on the counter as they land. [from] and [to] are in the painter's
/// own coordinates. Paints nothing before it starts or after it ends.
class CoinBurstPainter extends CustomPainter {
  static const int coinCount = 10;

  final Animation<double> progress;
  final Offset from;
  final Offset to;

  CoinBurstPainter({
    required this.progress,
    required this.from,
    required this.to,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0) return;

    for (var i = 0; i < coinCount; i++) {
      final start = 0.16 + i * 0.035;
      final u = ((t - start) / 0.5).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue; // not launched yet, or landed
      final e = Curves.easeInCubic.transform(u);
      // A curved path: up and out first, then in to the counter.
      final sway = (i - coinCount / 2) * 16.0;
      final control = Offset(
        (from.dx + to.dx) / 2 + sway,
        math.min(from.dy, to.dy) - 40,
      );
      final pos =
          from * ((1 - e) * (1 - e)) +
          control * (2 * (1 - e) * e) +
          to * (e * e);
      final radius = 11.0 * (1 - 0.3 * e);
      final alpha = u < 0.1 ? u / 0.1 : 1.0;
      _coin(canvas, pos, radius, alpha);
    }

    // The counter lights up as the first coins arrive.
    final q = ((t - 0.66) / 0.3).clamp(0.0, 1.0);
    if (q > 0 && q < 1) {
      canvas.drawCircle(
        to,
        20 + 26 * q,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Color.fromRGBO(255, 200, 40, 0.8 * (1 - q)),
      );
    }
  }

  void _coin(Canvas canvas, Offset p, double r, double alpha) {
    final rect = Rect.fromCircle(center: p, radius: r);
    canvas.drawCircle(
      p + Offset(0, r * 0.2),
      r,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.3 * alpha),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Color.fromRGBO(255, 240, 150, alpha),
            Color.fromRGBO(255, 184, 46, alpha),
            Color.fromRGBO(184, 116, 0, alpha),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      p,
      r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, r * 0.14)
        ..color = Color.fromRGBO(140, 84, 0, 0.7 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant CoinBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}

/// Little lights drifting slowly up the whole screen, twinkling as they go.
/// They speed up with [energy] (a spin in progress). Gold and white on the
/// dark background, amber and white on the light one. Keep one instance alive:
/// it remembers how far time has run.
class SparkleFieldPainter extends CustomPainter {
  static const int count = 34;

  final Animation<double> phase;
  final Animation<double> energy;
  final bool light;

  final SpinClock _clock = SpinClock();

  SparkleFieldPainter({
    required this.phase,
    required this.energy,
    required this.light,
  }) : super(repaint: Listenable.merge([phase, energy]));

  /// A repeatable "random" number from 0 to 1 for particle [i].
  static double _h(int i, double salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final e = energy.value;
    final t = _clock.advance(
      phase.value,
      SpinClock.ambientSeconds,
      1 + 1.8 * e,
    );

    for (var i = 0; i < count; i++) {
      final speed = 0.012 + 0.03 * _h(i, 1); // screens per second
      final progress = (_h(i, 2) + t * speed) % 1.0;
      final x = size.width * _h(i, 3) + math.sin(t * 0.7 + i) * 10;
      final y = size.height * (1 - progress);
      final radius = 1.3 + 2.2 * _h(i, 4);
      final twinkle = 0.5 + 0.5 * math.sin(t * (1.2 + _h(i, 5)) + i * 1.7);
      // Fade in at the bottom and out at the top.
      final fade = math.sin(math.pi * progress);
      final alpha = ((0.15 + 0.7 * twinkle * fade) * (0.7 + 0.3 * e)).clamp(
        0.0,
        1.0,
      );

      final white = _h(i, 6) > 0.5;
      final base = light
          ? (white ? const Color(0xFFFFFFFF) : const Color(0xFFE88A14))
          : (white ? const Color(0xFFFFF3D0) : const Color(0xFFFFC94A));
      final p = Offset(x, y);
      canvas.drawCircle(
        p,
        radius * 3,
        Paint()..color = base.withValues(alpha: alpha * 0.22),
      );
      canvas.drawCircle(
        p,
        radius,
        Paint()..color = base.withValues(alpha: alpha),
      );
      if (radius > 2.6) {
        // The bigger ones get a little four-point glint.
        final glint = Paint()
          ..color = base.withValues(alpha: alpha * 0.8)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        final len = radius * 2.6 * (0.6 + 0.4 * twinkle);
        canvas.drawLine(p - Offset(len, 0), p + Offset(len, 0), glint);
        canvas.drawLine(p - Offset(0, len), p + Offset(0, len), glint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SparkleFieldPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.energy != energy ||
      oldDelegate.light != light;
}
