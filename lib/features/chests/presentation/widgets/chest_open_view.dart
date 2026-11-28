import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chest_style.dart';
import '../chest_timeline.dart';
import 'chest_effects_painter.dart';

/// One chest. [progress] runs 0 (closed) to 1 (fully open); the film it plays is
/// described in [ChestTimeline]: the chest rattles, the lock breaks, the lid
/// cracks, the energy bursts, and it settles open directly and smoothly.
///
/// Every frame has the same canvas, so nothing shifts between them. The pictures
/// are pre-warmed and kept mounted in the tree at all times to prevent texture
/// decoding spikes or dropped frames. Bilinear hardware-accelerated filtering
/// ensures high-frame-rate rendering across all devices.
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

  /// Persistent picture of the chest at [opacity]. Kept mounted in the tree so
  /// GPU textures remain warm in VRAM without dynamic mounting overhead.
  Widget _frame(ChestFrame frame, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    return Positioned.fill(
      child: Opacity(
        opacity: clamped,
        child: Image.asset(
          style.frameAsset(frame),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          isAntiAlias: true,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          // Missing art must never break the screen: show nothing.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
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

                  // Closed, opening, burst and opened stack in that order;
                  // each fades in over the one before and the one before is
                  // dropped once covered.
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
                      filterQuality: FilterQuality.medium,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.medium,
                        child: stack,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (!reduceMotion)
            // The radiant flash that covers the lid opening pop.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) {
                    final f = ChestTimeline.flash(progress.value);
                    if (f < 0.01) return const SizedBox.shrink();
                    return Opacity(
                      opacity: f.clamp(0.0, 1.0),
                      child: OverflowBox(
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
                                )!.withValues(alpha: 0.85),
                                style.primary.withValues(alpha: 0.30),
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
