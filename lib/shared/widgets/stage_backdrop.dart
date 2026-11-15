import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A lit stage: a soft glow in the middle, thin rays fanning out behind it, and
/// a glowing disc on the floor. Used behind the hero of a screen (the character
/// on a result, a chest in the Chest Box) so they all feel lit the same way.
///
/// The painting only needs [accent], the colour of the light. [centerY] is how
/// far down (0 to 1) the light sits.
class StageBackdropPainter extends CustomPainter {
  final Color accent;
  final double centerY;

  StageBackdropPainter(this.accent, {this.centerY = 0.52});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * centerY);
    final reach = size.width * 0.9;

    // Rays: thin wedges around the centre that fade out towards the edge.
    const rays = 16;
    final wedge = 2 * math.pi / rays / 2;
    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: reach));
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + reach * math.cos(a - wedge / 2),
          center.dy + reach * math.sin(a - wedge / 2),
        )
        ..lineTo(
          center.dx + reach * math.cos(a + wedge / 2),
          center.dy + reach * math.sin(a + wedge / 2),
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // The glow right behind the hero.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.5), accent.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.4));
    canvas.drawCircle(center, size.width * 0.4, glow);

    // The floor under the hero's feet.
    final floor = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 14),
      width: size.width * 0.5,
      height: 26,
    );
    canvas.drawOval(
      floor,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.65), accent.withValues(alpha: 0)],
        ).createShader(floor),
    );
  }

  @override
  bool shouldRepaint(StageBackdropPainter old) =>
      old.accent != accent || old.centerY != centerY;
}
