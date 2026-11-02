import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../rewards/domain/rewards_models.dart';

const double _tau = 2 * math.pi;

/// Segment 0 starts at the top (12 o'clock) and segments run clockwise. The
/// pointer is fixed at the top, so after rotating the wheel clockwise by
/// [angle] the segment under the pointer is the one now at 12 o'clock.
int segmentIndexAtPointer(double angle, int segmentCount) {
  final sweep = _tau / segmentCount;
  final pointerAngleOnWheel = ((-angle) % _tau + _tau) % _tau;
  return (pointerAngleOnWheel / sweep).floor() % segmentCount;
}

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

/// Static artwork of the wheel. It never repaints while spinning: the screen
/// rotates it with a Transform inside a RepaintBoundary.
class SpinWheelPainter extends CustomPainter {
  final List<WheelSegment> segments;
  final Color rimColor;

  const SpinWheelPainter({required this.segments, required this.rimColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2;
    final radius = outer * 0.93;
    final sweep = _tau / segments.length;
    final face = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, outer, Paint()..color = rimColor);
    for (var i = 0; i < segments.length; i++) {
      final start = i * sweep - math.pi / 2;
      canvas.drawArc(
        face,
        start,
        sweep,
        true,
        Paint()..color = segments[i].color,
      );
      canvas.drawArc(
        face,
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    for (var i = 0; i < segments.length; i++) {
      final color = segments[i].color;
      final ink = color.computeLuminance() > 0.5
          ? const Color(0xFF1B1B2F)
          : Colors.white;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sweep + sweep / 2 - math.pi / 2);
      final text = TextPainter(
        text: TextSpan(
          text: '${segments[i].coins}',
          style: TextStyle(
            fontSize: radius * 0.16,
            fontWeight: FontWeight.w800,
            color: ink,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Number runs along the radius, centred in the segment.
      text.paint(canvas, Offset(radius * 0.38, -text.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.rimColor != rimColor;
}

/// Fixed pointer drawn above the top of the wheel, tip pointing down.
class WheelPointerPainter extends CustomPainter {
  final Color color;

  const WheelPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.05)
      ..lineTo(size.width * 0.9, size.height * 0.05)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant WheelPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}
