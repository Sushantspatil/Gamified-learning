import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../rewards_hub/data/rewards_mock_data.dart';
import '../../../rewards_hub/domain/rewards_models.dart';

const double _tau = 2 * math.pi;

/// Segment 0 starts at the top (12 o'clock) and segments run clockwise.
/// The pointer is fixed at the top, so after rotating the wheel clockwise by
/// [angle] the segment under the pointer is the one whose centre now sits at
/// 12 o'clock.
int segmentIndexAtPointer(double angle, int segmentCount) {
  final sweep = _tau / segmentCount;
  final pointerAngleOnWheel = ((-angle) % _tau + _tau) % _tau;
  return (pointerAngleOnWheel / sweep).floor() % segmentCount;
}

/// Total clockwise rotation that starts at [currentAngle], makes [turns]
/// extra full turns and finishes with segment [index] under the pointer.
/// [offsetFraction] (-0.4..0.4) shifts the stop point inside the segment so
/// the wheel does not always rest dead-centre; it never leaves the segment.
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

/// Static artwork of the wheel (rim, segments, labels). It never repaints
/// while spinning: the screen rotates it with a Transform inside a
/// RepaintBoundary, so only a layer matrix changes per frame.
class SpinWheelPainter extends CustomPainter {
  final List<WheelSegment> segments;
  final Color rimColor;
  final Color rimHighlight;

  const SpinWheelPainter({
    required this.segments,
    required this.rimColor,
    required this.rimHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2;
    final rim = outer * 0.07;
    final radius = outer - rim;
    final sweep = _tau / segments.length;
    final faceRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, outer, Paint()..color = rimColor);

    // Rim lights.
    final bulbPaint = Paint()..color = rimHighlight;
    for (var i = 0; i < segments.length * 2; i++) {
      final a = i * _tau / (segments.length * 2) - math.pi / 2;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * (outer - rim / 2),
        rim * 0.22,
        bulbPaint,
      );
    }

    for (var i = 0; i < segments.length; i++) {
      final start = i * sweep - math.pi / 2;
      canvas.drawArc(
        faceRect,
        start,
        sweep,
        true,
        Paint()..color = segments[i].color,
      );
      canvas.drawArc(
        faceRect,
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
      _paintSegmentContent(
        canvas,
        center,
        radius,
        i * sweep + sweep / 2 - math.pi / 2,
        segments[i],
      );
    }
  }

  void _paintSegmentContent(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    WheelSegment segment,
  ) {
    final ink = RewardsMockData.labelColorFor(segment.color);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Icon near the rim, upright relative to the radial axis.
    final icon = segment.reward.icon;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: radius * 0.17,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(radius * 0.78, 0);
    canvas.rotate(math.pi / 2);
    iconPainter.paint(
      canvas,
      Offset(-iconPainter.width / 2, -iconPainter.height / 2),
    );
    canvas.restore();

    // Label running along the radius.
    final labelPainter = TextPainter(
      text: TextSpan(
        text: segment.shortLabel,
        style: TextStyle(
          fontSize: radius * 0.083,
          fontWeight: FontWeight.w800,
          color: ink,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: radius * 0.4);
    labelPainter.paint(canvas, Offset(radius * 0.3, -labelPainter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.rimColor != rimColor ||
      oldDelegate.rimHighlight != rimHighlight;
}

/// Fixed pointer drawn above the top of the wheel, tip pointing down.
class WheelPointerPainter extends CustomPainter {
  final Color color;
  final Color outline;

  const WheelPointerPainter({required this.color, required this.outline});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.08)
      ..quadraticBezierTo(
        size.width / 2,
        -size.height * 0.04,
        size.width * 0.88,
        size.height * 0.08,
      )
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = outline,
    );
  }

  @override
  bool shouldRepaint(covariant WheelPointerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.outline != outline;
}
