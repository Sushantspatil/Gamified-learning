import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/spin_wheel_segment.dart';

class SpinWheelPainter extends CustomPainter {
  final List<SpinWheelSegment> segments;
  final String? highlightedSegmentId;

  SpinWheelPainter({required this.segments, this.highlightedSegmentId});

  static const List<Color> _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.coinGold,
    AppColors.gemCyan,
    AppColors.accentGold,
    AppColors.streakFire,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2;
    final sweep = 2 * pi / segments.length;

    for (var i = 0; i < segments.length; i++) {
      final paint = Paint()..color = _colors[i % _colors.length];
      final startAngle = i * sweep - pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );

      if (segments[i].id == highlightedSegmentId) {
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 2),
          startAngle,
          sweep,
          true,
          borderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) =>
      oldDelegate.highlightedSegmentId != highlightedSegmentId ||
      oldDelegate.segments != segments;
}
