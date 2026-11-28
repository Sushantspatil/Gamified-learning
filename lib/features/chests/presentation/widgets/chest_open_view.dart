import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chest_style.dart';
import '../chest_timeline.dart';
import 'chest_effects_painter.dart';

/// One chest. [progress] runs 0 (closed) to 1 (fully open); the film it plays is
/// described in [ChestTimeline]: the chest rattles, the lock breaks, the lid
/// cracks, the energy bursts, and it settles open.
///
/// Every frame has the same canvas, so nothing shifts between them. The pictures
/// are cut (a flash covers each cut) and never blended half and half, so the
/// chest is never see-through. This widget only draws; what happens on tap, and
/// the reward, belong to the screen.
class ChestOpenView extends StatelessWidget {
  final ChestStyle style;
  final Animation<double> progress;
  final double height;
  final bool reduceMotion;

  const ChestOpenView({
    super.key,
    required this.style,
    required this.progress,
    required this.height,
    this.reduceMotion = false,
  });

  /// One picture of the chest at [opacity]. High quality resampling keeps the
  /// edges clean when the chest is scaled up (it is drawn larger than its
  /// artwork on most phones).
  Widget _frame(ChestFrame frame, double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: Image.asset(
        style.frameAsset(frame),
        opacity: AlwaysStoppedAnimation<double>(opacity),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        // Missing art must never break the screen: show nothing.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = height * style.aspectRatio;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: ChestEffectsPainter(
                  style: style,
                  progress: progress,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: progress,
                builder: (context, _) {
                  final t = progress.value;
                  var angle = 0.0;
                  var dx = 0.0;
                  var dy = 0.0;
                  var scale = 1.0;
                  if (!reduceMotion) {
                    final rattle = ChestTimeline.rattle(t);
                    angle = rattle * 0.035;
                    dx = rattle * height * 0.014;
                    dy = ChestTimeline.lift(t) * height;
                    scale = ChestTimeline.scale(t);
                  }
                  // Closed, opening, burst and opened stack in that order; each
                  // fades in over the one before and the one before is dropped
                  // once covered.
                  final stack = Stack(
                    children: [
                      for (final frame in ChestFrame.values)
                        _frame(frame, ChestTimeline.opacityOf(frame, t)),
                    ],
                  );
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.rotate(
                      angle: angle,
                      alignment: Alignment.bottomCenter,
                      filterQuality: FilterQuality.high,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.high,
                        child: stack,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (!reduceMotion)
            // The flash that hides each cut: light leaving the chest.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) {
                    final f = ChestTimeline.flash(progress.value);
                    if (f < 0.01) return const SizedBox.shrink();
                    return OverflowBox(
                      maxWidth: width * 2.4,
                      maxHeight: height * 2.4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color.lerp(
                                Colors.white,
                                style.highlight,
                                0.35,
                              )!.withValues(alpha: 0.85 * f),
                              style.primary.withValues(alpha: 0.30 * f),
                              style.primary.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.35, 1.0],
                          ),
                        ),
                        child: SizedBox(
                          width: math.max(width, height) * 1.9,
                          height: math.max(width, height) * 1.9,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
