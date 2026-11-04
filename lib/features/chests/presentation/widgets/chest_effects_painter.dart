import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chest_style.dart';

/// Light and particles for one chest, driven by the opening progress `t`
/// (0 closed .. 1 fully open). Each chest has its own look:
///  * galaxy: purple/blue rays, twinkling four-point stars, a cosmic ring;
///  * golden: warm rays, rising flames and gold dust;
///  * cyber: crisp cyan rays, electric arcs, digital pulse rings, pixels.
///
/// Particle positions come from a fixed pseudo-random table, so frames are
/// repeatable and nothing is allocated per frame beyond the paths drawn.
/// It paints outside its own box (the chest is the focal point), so the owner
/// should clip it to the area it is allowed to light up.
class ChestEffectsPainter extends CustomPainter {
  final ChestStyle style;
  final Animation<double> progress;

  /// Skip motion effects (reduce-motion); only a soft static glow is drawn.
  final bool reduceMotion;

  ChestEffectsPainter({
    required this.style,
    required this.progress,
    this.reduceMotion = false,
  }) : super(repaint: progress);

  static double _rand(int i, int k) {
    final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  static double _ramp(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0.001) return;

    final h = size.height;
    // Light pours out of the opening, a little above the chest's middle.
    final origin = Offset(size.width / 2, h * 0.36);

    // Glow builds as the lid lifts, peaks in the burst, then settles.
    final build = _ramp(t, 0.10, 0.42);
    final burst = math.sin(_ramp(t, 0.38, 0.78) * math.pi); // 0..1..0
    final linger = _ramp(t, 0.72, 0.85);
    final glow = math.max(build * 0.55, math.max(burst, linger * 0.65));

    _glow(canvas, origin, h, glow);
    if (reduceMotion) return;

    _rays(canvas, origin, h, burst, t);
    switch (style) {
      case ChestStyle.galaxy:
        _galaxy(canvas, origin, h, t, burst, linger);
      case ChestStyle.golden:
        _golden(canvas, origin, h, t, burst, linger);
      case ChestStyle.cyber:
        _cyber(canvas, origin, h, t, burst, linger);
    }
  }

  void _glow(Canvas canvas, Offset o, double h, double amount) {
    if (amount <= 0) return;
    final r = h * (0.38 + 0.28 * amount);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            style.highlight.withValues(alpha: 0.85 * amount),
            style.primary.withValues(alpha: 0.45 * amount),
            style.primary.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void _rays(Canvas canvas, Offset o, double h, double burst, double t) {
    if (burst <= 0.02) return;
    final count = style == ChestStyle.cyber ? 10 : 14;
    final length = h * (0.30 + 0.34 * burst);
    final spin = style == ChestStyle.galaxy ? t * 0.5 : 0.0;
    // Rays fan upward and outward from the opening.
    for (var i = 0; i < count; i++) {
      final a =
          -math.pi / 2 +
          (i / (count - 1) - 0.5) * math.pi * 1.25 +
          (style == ChestStyle.galaxy ? math.sin(spin + i) * 0.05 : 0);
      final half = style == ChestStyle.cyber ? 0.035 : 0.055;
      final len = length * (0.7 + 0.3 * _rand(i, 3));
      final path = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(
          o.dx + math.cos(a - half) * len,
          o.dy + math.sin(a - half) * len,
        )
        ..lineTo(
          o.dx + math.cos(a + half) * len,
          o.dy + math.sin(a + half) * len,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              (i.isEven ? style.highlight : style.primary).withValues(
                alpha: 0.55 * burst,
              ),
              style.primary.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: len)),
      );
    }
  }

  // ---- Galaxy: cosmic sparkles, floating dust and an expanding ring -------

  void _galaxy(
    Canvas c,
    Offset o,
    double h,
    double t,
    double burst,
    double linger,
  ) {
    final ring = _ramp(t, 0.40, 0.70);
    if (ring > 0 && ring < 1) {
      c.drawCircle(
        o,
        h * (0.12 + 0.5 * ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.02 * (1 - ring)
          ..color = style.secondary.withValues(alpha: 0.8 * (1 - ring)),
      );
    }
    final show = math.max(burst, linger * 0.8);
    for (var i = 0; i < 22; i++) {
      final angle = -math.pi / 2 + (_rand(i, 1) - 0.5) * math.pi * 1.5;
      final dist =
          h * (0.15 + 0.5 * _rand(i, 2)) * (0.4 + 0.6 * _ramp(t, 0.35, 0.9));
      // Floating drift once the burst is over.
      final drift = Offset(
        math.sin(t * 6 + i) * h * 0.012,
        -linger * h * 0.05 * _rand(i, 4),
      );
      final p = o + Offset(math.cos(angle), math.sin(angle)) * dist + drift;
      final twinkle = 0.5 + 0.5 * math.sin(t * 28 + i * 2.1);
      final color = style.colors[i % 3].withValues(
        alpha: show * (0.35 + 0.65 * twinkle),
      );
      _star(c, p, h * (0.012 + 0.022 * _rand(i, 5)) * (0.6 + twinkle), color);
    }
  }

  void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r * 2.2)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r * 2.2, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r * 2.2)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r * 2.2, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r * 2.2)
      ..close();
    c.drawPath(path, Paint()..color = color);
  }

  // ---- Golden: rising flames and gold dust --------------------------------

  void _golden(
    Canvas c,
    Offset o,
    double h,
    double t,
    double burst,
    double linger,
  ) {
    final show = math.max(burst, linger * 0.7);
    // Flames: teardrops that rise, sway and fade.
    for (var i = 0; i < 12; i++) {
      final life = (t * 1.6 + _rand(i, 1)) % 1.0;
      final x =
          o.dx +
          (_rand(i, 2) - 0.5) * h * 0.55 +
          math.sin(life * 7 + i) * h * 0.03;
      final y = o.dy - life * h * (0.35 + 0.3 * _rand(i, 3));
      final r = h * (0.045 + 0.05 * _rand(i, 4)) * (1 - life * 0.6);
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: r * 1.4,
        height: r * 2.6,
      );
      c.drawOval(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              style.secondary.withValues(alpha: 0.9 * show * (1 - life)),
              style.primary.withValues(alpha: 0.6 * show * (1 - life)),
              style.highlight.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
    // Gold dust.
    for (var i = 0; i < 24; i++) {
      final angle = -math.pi / 2 + (_rand(i, 6) - 0.5) * math.pi * 1.6;
      final dist =
          h * (0.1 + 0.55 * _rand(i, 7)) * (0.35 + 0.65 * _ramp(t, 0.35, 0.95));
      final p = o + Offset(math.cos(angle), math.sin(angle)) * dist;
      final tw = 0.5 + 0.5 * math.sin(t * 24 + i * 1.7);
      c.drawCircle(
        p,
        h * (0.008 + 0.012 * _rand(i, 8)) * (0.7 + tw),
        Paint()
          ..color = style.colors[i % 3].withValues(
            alpha: show * (0.4 + 0.6 * tw),
          ),
      );
    }
  }

  // ---- Cyber: electric arcs, pulse rings and pixels ------------------------

  void _cyber(
    Canvas c,
    Offset o,
    double h,
    double t,
    double burst,
    double linger,
  ) {
    final show = math.max(burst, linger * 0.7);
    // Digital pulse rings.
    for (var k = 0; k < 3; k++) {
      final p = _ramp(t, 0.36 + k * 0.08, 0.70 + k * 0.08);
      if (p <= 0 || p >= 1) continue;
      final r = h * (0.1 + 0.55 * p);
      final rect = Rect.fromCenter(center: o, width: r * 2, height: r * 1.3);
      c.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r * 0.35)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.012
          ..color = style.primary.withValues(alpha: 0.8 * (1 - p)),
      );
    }
    // Electric arcs: zig-zag lines whose jitter changes in steps (~12 fps),
    // so they crackle rather than glide.
    final step = (t * 14).floor();
    for (var i = 0; i < 7; i++) {
      final base = -math.pi / 2 + (i / 6 - 0.5) * math.pi * 1.3;
      final len = h * (0.25 + 0.32 * _rand(i, 9 + step % 5));
      final path = Path()..moveTo(o.dx, o.dy);
      const segments = 6;
      for (var s = 1; s <= segments; s++) {
        final d = len * s / segments;
        final jitter = (_rand(i * 7 + s, step) - 0.5) * h * 0.09;
        path.lineTo(
          o.dx + math.cos(base) * d - math.sin(base) * jitter,
          o.dy + math.sin(base) * d + math.cos(base) * jitter,
        );
      }
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = h * 0.011
          ..color = style.highlight.withValues(alpha: 0.9 * show),
      );
    }
    // Pixel particles.
    for (var i = 0; i < 22; i++) {
      final angle = -math.pi / 2 + (_rand(i, 11) - 0.5) * math.pi * 1.6;
      final dist =
          h *
          (0.12 + 0.55 * _rand(i, 12)) *
          (0.35 + 0.65 * _ramp(t, 0.35, 0.95));
      final p = o + Offset(math.cos(angle), math.sin(angle)) * dist;
      final side = h * (0.014 + 0.016 * _rand(i, 13));
      final blink = ((t * 10 + i) % 1.0) < 0.7 ? 1.0 : 0.3;
      c.drawRect(
        Rect.fromCenter(center: p, width: side, height: side),
        Paint()..color = style.colors[i % 3].withValues(alpha: show * blink),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ChestEffectsPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.progress != progress ||
      oldDelegate.reduceMotion != reduceMotion;
}
