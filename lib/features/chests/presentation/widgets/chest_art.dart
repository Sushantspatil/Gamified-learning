import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector treasure chest. [open] runs 0 (closed) → 1 (fully open) and the
/// painter repaints from it directly, so animating a chest never rebuilds
/// the screen. A short shake plays during the first part of [open].
class ChestArt extends StatelessWidget {
  final Animation<double> open;
  final Color color;
  final Color colorDark;
  final bool dimmed;
  final double size;

  const ChestArt({
    super.key,
    required this.open,
    required this.color,
    required this.colorDark,
    this.dimmed = false,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: open,
        builder: (context, child) {
          // Shake only during the wind-up (first third), then settle.
          final t = open.value;
          final shake = t > 0 && t < 0.3
              ? math.sin(t / 0.3 * math.pi * 6) * 3 * (1 - t / 0.3)
              : 0.0;
          return Transform.translate(offset: Offset(shake, 0), child: child);
        },
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: CustomPaint(
            size: Size(size, size * 0.94),
            painter: _ChestPainter(
              open: open,
              color: color,
              colorDark: colorDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChestPainter extends CustomPainter {
  final Animation<double> open;
  final Color color;
  final Color colorDark;

  _ChestPainter({
    required this.open,
    required this.color,
    required this.colorDark,
  }) : super(repaint: open);

  static const Color _metal = Color(0xFFFFD66B);
  static const Color _metalDark = Color(0xFFB27A00);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Lid lifts after the shake: map 0.3..0.85 to 0..1.
    final lift = ((open.value - 0.3) / 0.55).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(lift).clamp(0.0, 1.2);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.46, w * 0.84, h * 0.46),
      Radius.circular(w * 0.06),
    );

    // Inside + glow, revealed as the lid opens.
    if (lift > 0) {
      final glowCenter = Offset(w * 0.5, h * 0.42);
      canvas.drawCircle(
        glowCenter,
        w * (0.35 + 0.25 * lift),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE9A3).withValues(alpha: 0.85 * lift),
              _metal.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: glowCenter, radius: w * 0.6)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.12, h * 0.44, w * 0.76, h * 0.1),
          Radius.circular(w * 0.04),
        ),
        Paint()..color = const Color(0xFF2A1A08),
      );
    }

    // Body.
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, colorDark],
        ).createShader(bodyRect.outerRect),
    );
    final band = Paint()..color = _metal;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.66, w * 0.84, h * 0.05),
      band,
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.46, w * 0.06, h * 0.46), band);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.74, h * 0.46, w * 0.06, h * 0.46),
      band,
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _metalDark,
    );

    // Lid: rises and flattens a little as it opens.
    canvas.save();
    canvas.translate(0, -eased * h * 0.2);
    canvas.translate(w * 0.5, h * 0.5);
    canvas.scale(1, 1 - 0.35 * lift);
    canvas.translate(-w * 0.5, -h * 0.5);
    final lid = Path()
      ..moveTo(w * 0.08, h * 0.5)
      ..lineTo(w * 0.08, h * 0.34)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w * 0.92, h * 0.34)
      ..lineTo(w * 0.92, h * 0.5)
      ..close();
    canvas.drawPath(
      lid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, Color.lerp(color, colorDark, 0.6)!],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5)),
    );
    canvas.drawPath(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _metalDark,
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.06, h * 0.3), band);
    canvas.drawRect(Rect.fromLTWH(w * 0.74, h * 0.2, w * 0.06, h * 0.3), band);
    canvas.restore();

    // Latch (fades away once open).
    final latchOpacity = (1 - lift * 2).clamp(0.0, 1.0);
    if (latchOpacity > 0) {
      final latch = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.52),
          width: w * 0.16,
          height: h * 0.16,
        ),
        Radius.circular(w * 0.03),
      );
      canvas.drawRRect(
        latch,
        Paint()..color = _metal.withValues(alpha: latchOpacity),
      );
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.52),
        w * 0.02,
        Paint()..color = _metalDark.withValues(alpha: latchOpacity),
      );
    }

    // Sparkles above an open chest.
    if (lift > 0.6) {
      final sparkle = Paint()..color = Colors.white.withValues(alpha: lift);
      for (final p in const [
        Offset(0.28, 0.12),
        Offset(0.5, 0.02),
        Offset(0.74, 0.14),
      ]) {
        canvas.drawCircle(Offset(w * p.dx, h * p.dy), w * 0.025, sparkle);
      }
    }
  }

  @override
  bool shouldRepaint(_ChestPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.colorDark != colorDark ||
      oldDelegate.open != open;
}
