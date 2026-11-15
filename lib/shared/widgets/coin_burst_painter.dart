import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Coins that fly from one spot (a reward, the wheel) to the coin counter, and
/// a ring that pulses on the counter as they land. [from] and [to] are in the painter's
/// own coordinates. Paints nothing before it starts or after it ends.
class CoinBurstPainter extends CustomPainter {
  final Animation<double> progress;
  final Offset from;
  final Offset to;

  /// How many coins fly.
  final int coinCount;

  CoinBurstPainter({
    required this.progress,
    required this.from,
    required this.to,
    this.coinCount = 10,
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
      oldDelegate.to != to ||
      oldDelegate.coinCount != coinCount;
}
