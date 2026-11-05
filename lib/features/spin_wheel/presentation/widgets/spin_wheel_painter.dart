import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../rewards/domain/rewards_models.dart';
import 'spin_wheel_motion.dart';

const double _tau = 2 * math.pi;

/// Segment 0 starts at the top (12 o'clock) and segments run clockwise. The
/// pointer is fixed at the top, so after rotating the wheel clockwise by
/// [angle] the segment under the pointer is the one now at 12 o'clock.
int segmentIndexAtPointer(double angle, int segmentCount) {
  final sweep = _tau / segmentCount;
  final pointerAngleOnWheel = ((-angle) % _tau + _tau) % _tau;
  return (pointerAngleOnWheel / sweep).floor() % segmentCount;
}

/// Rotation at which segment [index] is centred under the pointer.
double wheelRestAngle(int index, int segmentCount) =>
    -(index + 0.5) * _tau / segmentCount;

/// Total clockwise rotation from [currentAngle] that makes [turns] extra full
/// turns and ends with segment [index] under the pointer. [offsetFraction]
/// (-0.4..0.4) moves the stop point inside the segment, never out of it.
double wheelTargetAngle({
  required int index,
  required int segmentCount,
  required double currentAngle,
  required int turns,
  double offsetFraction = 0,
}) {
  final sweep = _tau / segmentCount;
  final stop = _tau - (index + 0.5 + offsetFraction.clamp(-0.4, 0.4)) * sweep;
  final base = currentAngle - (currentAngle % _tau);
  var target = base + stop;
  if (target <= currentAngle) target += _tau;
  return target + turns * _tau;
}

// ---- Palette (matches the casino prize-wheel reference) --------------------

const Color _goldLight = Color(0xFFFFEFA8);
const Color _goldMid = Color(0xFFF2B01E);
const Color _goldDark = Color(0xFFB87400);
const Color _bronze = Color(0xFF6E3F00);
const Color _labelOnGold = Color(0xFF8A0E00);
const Color _labelOnRed = Color(0xFFFFC21A);

/// Radius of the segmented face as a fraction of the whole wheel radius; the
/// rest is the metallic ring with the bulbs.
const double _faceRadius = 0.80;

/// Where the pegs sit, as a fraction of the wheel radius (just inside the
/// rim, level with the tip of the pointer).
const double pegCenterRadius = 0.757;

/// The spinning part: ten alternating red/gold segments with radial labels.
/// It never repaints while spinning (the screen rotates it with a Transform
/// inside a RepaintBoundary), so only a layer matrix changes per frame.
class SpinWheelPainter extends CustomPainter {
  final List<WheelSegment> segments;
  final TextStyle labelStyle;

  const SpinWheelPainter({required this.segments, required this.labelStyle});

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final face = r * _faceRadius;
    // Slightly under the bezel so no hairline gap shows between face and ring.
    final faceRect = Rect.fromCircle(center: c, radius: face + r * 0.012);
    final sweep = _tau / segments.length;

    for (var i = 0; i < segments.length; i++) {
      canvas.drawArc(
        faceRect,
        i * sweep - math.pi / 2,
        sweep,
        true,
        Paint()..color = segments[i].color,
      );
    }

    // Depth: brighter toward the middle, a little darker at the rim.
    canvas.drawCircle(
      c,
      face + r * 0.012,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x00000000), Color(0x40300000)],
          stops: [0.0, 0.62, 1.0],
        ).createShader(faceRect),
    );

    // Crisp divisions, all from the exact centre.
    final line = Paint()
      ..color = const Color(0xB35A0000)
      ..strokeWidth = math.max(1.0, r * 0.009)
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < segments.length; i++) {
      final a = i * sweep - math.pi / 2;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * face, line);
    }

    // Bevel: a thin highlight right beside every divider, so the segments
    // look raised rather than flat.
    final bevel = Paint()
      ..color = const Color(0x45FFF1B0)
      ..strokeWidth = math.max(1.0, r * 0.006)
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < segments.length; i++) {
      final a = i * sweep - math.pi / 2 + 0.014;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r * 0.2), c + dir * face, bevel);
    }

    for (var i = 0; i < segments.length; i++) {
      _label(canvas, c, r, i * sweep + sweep / 2 - math.pi / 2, segments[i]);
    }

    // Gold pegs between the prizes, where the pointer flapper catches.
    final pegRadius = r * 0.021;
    for (var i = 0; i < segments.length; i++) {
      final a = i * sweep - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * pegCenterRadius);
      canvas.drawCircle(
        p + Offset(r * 0.004, r * 0.009),
        pegRadius * 1.1,
        Paint()..color = const Color(0x77000000),
      );
      canvas.drawCircle(
        p,
        pegRadius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFFFFF3B0), Color(0xFFE0A21A), Color(0xFF7A4600)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: p, radius: pegRadius)),
      );
    }
  }

  /// Bold label running along the segment's radius, kept clear of the hub and
  /// of the ring by scaling it down if it is too long.
  void _label(Canvas canvas, Offset c, double r, double angle, WheelSegment s) {
    final onGold = s.color.computeLuminance() > 0.35;
    final inner = r * 0.30; // clear of the hub
    final outer = r * 0.74; // clear of the ring
    final maxWidth = outer - inner;
    var fontSize = r * 0.19;

    TextPainter layout(double size) => TextPainter(
      text: TextSpan(
        text: '${s.coins}'.toUpperCase(),
        style: labelStyle.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          height: 1,
          color: onGold ? _labelOnGold : _labelOnRed,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    var painter = layout(fontSize);
    if (painter.width > maxWidth) {
      fontSize *= maxWidth / painter.width;
      painter = layout(fontSize);
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    // Centred in the band between hub and ring, reading outward.
    final x = inner + (maxWidth - painter.width) / 2;
    painter.paint(canvas, Offset(x, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.labelStyle != labelStyle;
}

/// The fixed frame: metallic golden ring with concentric outlines, plus the
/// 3D centre hub. Static, so it is painted once and cached.
class WheelRingPainter extends CustomPainter {
  const WheelRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final outerRect = Rect.fromCircle(center: c, radius: r);

    // Soft drop shadow under the whole wheel.
    canvas.drawCircle(
      c + Offset(0, r * 0.03),
      r * 1.01,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0x00000000),
            Color(0x66000000),
            Color(0x00000000),
          ],
          stops: const [0.93, 0.985, 1.12],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.12)),
    );

    // Metallic band: a sweep gradient with bright and dark bands gives the
    // brushed-gold look; a radial layer adds the bevel.
    final band = Path()
      ..addOval(outerRect)
      ..addOval(Rect.fromCircle(center: c, radius: r * _faceRadius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      band,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            _goldLight,
            _goldMid,
            _goldDark,
            _goldMid,
            _goldLight,
            _goldMid,
            _goldDark,
            _goldMid,
            _goldLight,
          ],
        ).createShader(outerRect),
    );
    canvas.drawPath(
      band,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0x55000000),
            Color(0x00000000),
            Color(0x00FFFFFF),
            Color(0x66000000),
          ],
          stops: const [0.78, 0.86, 0.96, 1.0],
        ).createShader(outerRect),
    );

    // Concentric golden outlines (dark groove with a bright edge beside it).
    void outline(double fraction, {double width = 0.010}) {
      final radius = r * fraction;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * width
          ..color = const Color(0xFF7A4600),
      );
      canvas.drawCircle(
        c,
        radius - r * width,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * width * 0.7
          ..color = const Color(0xCCFFF3B8),
      );
    }

    outline(0.995, width: 0.008);
    outline(0.955);
    outline(0.835);
    // Inner bezel lip where the ring meets the face.
    canvas.drawCircle(
      c,
      r * (_faceRadius + 0.004),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.016
        ..color = const Color(0xFF5A3200),
    );

    _hub(canvas, c, r * 0.17);
  }

  void _hub(Canvas canvas, Offset c, double hr) {
    // Cast shadow, then metallic rings, then the domed centre.
    canvas.drawCircle(
      c + Offset(0, hr * 0.12),
      hr * 1.12,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x99000000), Color(0x00000000)],
          stops: [0.78, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: hr * 1.2)),
    );
    final hubRect = Rect.fromCircle(center: c, radius: hr);
    canvas.drawCircle(
      c,
      hr,
      Paint()
        ..shader = const SweepGradient(
          colors: [_goldLight, _goldDark, _goldMid, _goldDark, _goldLight],
        ).createShader(hubRect),
    );
    for (final f in const [0.97, 0.82, 0.66]) {
      canvas.drawCircle(
        c,
        hr * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, hr * 0.045)
          ..color = f == 0.82
              ? const Color(0xCCFFF3B8)
              : const Color(0xFF6B3E00),
      );
    }
    final dome = Rect.fromCircle(center: c, radius: hr * 0.6);
    canvas.drawCircle(
      c,
      hr * 0.6,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFF7C94A), Color(0xFFB77A00), _bronze],
          stops: [0.0, 0.55, 1.0],
        ).createShader(dome),
    );
    // Small specular highlight.
    canvas.drawCircle(
      c + Offset(-hr * 0.2, -hr * 0.24),
      hr * 0.13,
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant WheelRingPainter oldDelegate) => false;
}

/// How the bulbs behave: trading brightness in pairs while waiting, running
/// round the ring while spinning, all flashing together on a win.
enum WheelBulbMode { twinkle, chase, flash }

/// The LED bulbs around the ring. Even and odd bulbs trade brightness as
/// [phase] (0..1) moves, so the wheel looks alive.
class WheelBulbsPainter extends CustomPainter {
  static const int bulbCount = 30;

  final Animation<double>? phase;
  final double staticPhase;
  final WheelBulbMode mode;

  WheelBulbsPainter({
    this.phase,
    this.staticPhase = 0.5,
    this.mode = WheelBulbMode.twinkle,
  }) : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final ringRadius = r * 0.88;
    final bulb = r * 0.039;
    final t = phase?.value ?? staticPhase;

    for (var i = 0; i < bulbCount; i++) {
      // Offset by half a step so no bulb hides under the pointer.
      final a = (i + 0.5) * _tau / bulbCount - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * ringRadius;
      final lit = switch (mode) {
        WheelBulbMode.twinkle => 0.5 + 0.5 * (i.isEven ? t : 1 - t),
        // Five bright patches running round the ring.
        WheelBulbMode.chase =>
          math
              .pow(0.5 + 0.5 * math.cos(_tau * (i * 5 / bulbCount - t)), 2)
              .toDouble(),
        WheelBulbMode.flash => 0.3 + 0.7 * t,
      };

      // Shadow, then the recessed socket.
      canvas.drawCircle(
        p + Offset(0, bulb * 0.4),
        bulb * 1.45,
        Paint()..color = const Color(0x66000000),
      );
      canvas.drawCircle(
        p,
        bulb * 1.35,
        Paint()..color = const Color(0xFF7A4600),
      );
      canvas.drawCircle(
        p,
        bulb * 1.2,
        Paint()..color = const Color(0xFF3A2000),
      );

      // Halo.
      final haloRect = Rect.fromCircle(center: p, radius: bulb * 3.6);
      canvas.drawCircle(
        p,
        bulb * 3.6,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 190, 60, 0.55 * lit),
              const Color(0x00FFB400),
            ],
          ).createShader(haloRect),
      );

      // Bright white-yellow core with a golden edge.
      final core = Rect.fromCircle(center: p, radius: bulb);
      canvas.drawCircle(
        p,
        bulb,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(const Color(0xFFFFE9A0), Colors.white, lit)!,
              Color.lerp(
                const Color(0xFFD99A10),
                const Color(0xFFFFD34A),
                lit,
              )!,
            ],
          ).createShader(core),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WheelBulbsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.staticPhase != staticPhase ||
      oldDelegate.mode != mode;
}

/// The golden pointer at the top, tip pointing down into the face. It hangs
/// from a pivot and is flicked aside by every peg that passes under it, then
/// springs back (see [wheelPointerDeflection]). When the wheel is too fast for
/// individual flicks to be seen, it is held part-way over instead of strobing.
class WheelPointerPainter extends CustomPainter {
  /// The wheel rotation; null draws a pointer at rest.
  final Animation<double>? rotation;
  final int segmentCount;

  /// The widest swing, in radians.
  static const double maxSwing = 0.5;

  double? _lastAngle;

  WheelPointerPainter({this.rotation, this.segmentCount = 10})
    : super(repaint: rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final halfWidth = r * 0.062;
    final top = c.dy - r * 0.945;
    final tip = c.dy - r * 0.715;
    final path = Path()
      ..moveTo(c.dx - halfWidth, top)
      ..lineTo(c.dx + halfWidth, top)
      ..lineTo(c.dx, tip)
      ..close();

    var swing = 0.0;
    final angle = rotation?.value;
    if (angle != null) {
      final sweep = _tau / segmentCount;
      final perFrame = _lastAngle == null
          ? 0.0
          : (angle - _lastAngle!).abs() / sweep; // segments moved this frame
      _lastAngle = angle;
      final fast = ((perFrame - 0.12) / 0.25).clamp(0.0, 1.0);
      final wave = wheelPointerDeflection(angle, segmentCount);
      swing = (wave + (-0.55 - wave) * fast) * maxSwing;
    }

    final pivot = Offset(c.dx, top + r * 0.03);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(swing);
    canvas.translate(-pivot.dx, -pivot.dy);

    canvas.drawPath(
      path.shift(Offset(0, r * 0.012)),
      Paint()..color = const Color(0x88000000),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3B0), Color(0xFFFFC21A), Color(0xFFD08A00)],
            ).createShader(
              Rect.fromLTRB(c.dx - halfWidth, top, c.dx + halfWidth, tip),
            ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1.0, r * 0.011)
        ..color = const Color(0xFF5A2E00),
    );
    canvas.restore();

    // The pivot rivet stays put.
    canvas.drawCircle(
      pivot,
      r * 0.026,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF3B0), Color(0xFFB87400)],
        ).createShader(Rect.fromCircle(center: pivot, radius: r * 0.026)),
    );
  }

  @override
  bool shouldRepaint(covariant WheelPointerPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.segmentCount != segmentCount;
}

/// A glassy sheen over the face: a soft light from the top left and a faint
/// specular streak. Static, so it is painted once and cached.
class WheelGlossPainter extends CustomPainter {
  const WheelGlossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final face = Rect.fromCircle(center: c, radius: r * _faceRadius);

    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    canvas.drawRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.3, 0.2),
          colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        ).createShader(face),
    );
    // Inner shadow hugging the rim, as if the face sat below the bezel.
    canvas.drawCircle(
      c,
      r * _faceRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(c.dx - r * 0.3, c.dy - r * 0.42);
    canvas.rotate(-0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.55, height: r * 0.1),
      Paint()
        ..color = const Color(0x24FFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WheelGlossPainter oldDelegate) => false;
}

/// Streaks over the face while it turns fast, so a spinning wheel looks
/// blurred rather than like a still picture being rotated. Invisible when the
/// wheel is slow or stopped.
class WheelSpeedBlurPainter extends CustomPainter {
  final Animation<double> rotation;
  final int segmentCount;

  double? _lastAngle;

  WheelSpeedBlurPainter({required this.rotation, required this.segmentCount})
    : super(repaint: rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final angle = rotation.value;
    final sweep = _tau / segmentCount;
    final perFrame = _lastAngle == null
        ? 0.0
        : (angle - _lastAngle!).abs() / sweep;
    _lastAngle = angle;
    final strength = ((perFrame - 0.08) / 0.5).clamp(0.0, 1.0);
    if (strength <= 0) return;

    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final face = Rect.fromCircle(center: c, radius: r * _faceRadius);
    final colour = Color.fromRGBO(255, 244, 214, 0.42 * strength);
    const clear = Color(0x00FFF4D6);

    // One soft band per prize, turning with the wheel.
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i < segmentCount; i++) {
      colors
        ..add(clear)
        ..add(colour);
      stops
        ..add(i / segmentCount)
        ..add((i + 0.5) / segmentCount);
    }
    colors.add(clear);
    stops.add(1.0);

    canvas.drawCircle(
      c,
      r * _faceRadius,
      Paint()
        ..shader = SweepGradient(
          colors: colors,
          stops: stops,
          transform: GradientRotation(angle - math.pi / 2),
        ).createShader(face),
    );
  }

  @override
  bool shouldRepaint(covariant WheelSpeedBlurPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.segmentCount != segmentCount;
}

/// Fiery glow and soft light rays behind the wheel. It paints well outside
/// its own box (the wheel is the focal point), so the caller must not clip it.
class WheelBackdropPainter extends CustomPainter {
  const WheelBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;

    // Wide orange-red glow.
    final glow = Rect.fromCircle(center: c, radius: r * 2.1);
    canvas.drawCircle(
      c,
      r * 2.1,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xCCFF8A1F), Color(0x66E8420F), Color(0x00B01010)],
          stops: [0.45, 0.72, 1.0],
        ).createShader(glow),
    );

    // Radial rays: narrow wedges fading outwards.
    const rays = 18;
    final rayRect = Rect.fromCircle(center: c, radius: r * 2.4);
    final rayPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x38FFC070), Color(0x00FFC070)],
        stops: [0.4, 1.0],
      ).createShader(rayRect);
    for (var i = 0; i < rays; i++) {
      final a = i * _tau / rays;
      const half = 0.07;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + math.cos(a - half) * r * 2.4,
            c.dy + math.sin(a - half) * r * 2.4,
          )
          ..lineTo(
            c.dx + math.cos(a + half) * r * 2.4,
            c.dy + math.sin(a + half) * r * 2.4,
          )
          ..close(),
        rayPaint,
      );
    }

    // Golden halo hugging the rim so the wheel stands out.
    final halo = Rect.fromCircle(center: c, radius: r * 1.3);
    canvas.drawCircle(
      c,
      r * 1.3,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00FFC21A), Color(0xCCFFB84A), Color(0x00FF9A1F)],
          stops: [0.74, 0.84, 1.0],
        ).createShader(halo),
    );
  }

  @override
  bool shouldRepaint(covariant WheelBackdropPainter oldDelegate) => false;
}
