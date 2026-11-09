import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/motion/app_motion.dart';
import '../../../app/theme/app_theme_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../domain/daily_ring.dart';

/// Today's goals as a ring: one slice per goal that fills as the goal does. A
/// finished slice turns gold; with every slice done the middle shows a check.
class DailyRing extends StatelessWidget {
  final List<RingSegment> segments;
  final double size;

  /// What sits in the middle. Defaults to "done/total", or a check when all done.
  final Widget? center;

  const DailyRing({
    super.key,
    required this.segments,
    this.size = 64,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final done = ringDone(segments);
    final allDone = segments.isNotEmpty && done == segments.length;

    final middle =
        center ??
        (allDone
            ? Icon(
                Icons.check_rounded,
                color: colors.warning,
                size: size * 0.46,
              )
            : Text(
                '$done/${segments.length}',
                style: context.appTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.26,
                ),
              ));

    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            // Fills from empty the first time it appears, and ticks up when a
            // goal moves.
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppMotion.duration(context, AppMotion.celebration),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                segments: segments,
                progress: t,
                track: colors.primary.withValues(alpha: 0.16),
                fill: colors.primary,
                done: colors.warning,
              ),
            ),
          ),
          middle,
        ],
      ),
    );

    return Semantics(
      label: 'Daily goals',
      value: '$done of ${segments.length} done',
      child: ExcludeSemantics(child: ring),
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<RingSegment> segments;
  final double progress; // 0..1 entrance
  final Color track;
  final Color fill;
  final Color done;

  _RingPainter({
    required this.segments,
    required this.progress,
    required this.track,
    required this.fill,
    required this.done,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final stroke = size.width * 0.13;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final count = segments.length;
    // A small gap between slices (none when there is only one).
    final gap = count == 1 ? 0.0 : 0.16;
    final slice = (2 * math.pi - gap * count) / count;

    Paint paint(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    var start = -math.pi / 2 + gap / 2;
    for (final segment in segments) {
      canvas.drawArc(rect, start, slice, false, paint(track));
      final sweep = slice * segment.fraction * progress;
      if (sweep > 0.001) {
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          paint(segment.complete ? done : fill),
        );
      }
      start += slice + gap;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.segments.length != segments.length ||
      !_sameFractions(old.segments, segments);

  static bool _sameFractions(List<RingSegment> a, List<RingSegment> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i].fraction != b[i].fraction) return false;
    }
    return true;
  }
}
