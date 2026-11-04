import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chest_style.dart';
import 'chest_effects_painter.dart';

/// Opacity of one frame over the opening progress: fades in over
/// [inStart]..[inEnd], stays, then fades out over [outStart]..[outEnd].
class _FrameWindow extends Animatable<double> {
  final double inStart, inEnd, outStart, outEnd;

  const _FrameWindow(this.inStart, this.inEnd, this.outStart, this.outEnd);

  @override
  double transform(double t) {
    final fadeIn = ((t - inStart) / (inEnd - inStart)).clamp(0.0, 1.0);
    final fadeOut = 1 - ((t - outStart) / (outEnd - outStart)).clamp(0.0, 1.0);
    return fadeIn * fadeOut;
  }
}

/// One chest. [progress] runs 0 (closed) to 1 (fully open) and the chest's
/// four artwork frames are cross-faded along it:
///
///   0.00-0.10  closed (rattles)
///   0.10-0.20  closed -> lid starts opening
///   0.38-0.46  opening -> energy burst
///   0.72-0.80  burst -> fully open
///
/// Every frame has the same canvas, so nothing shifts between them. The chest
/// itself rattles before opening and pops at the burst. This widget only
/// draws; what happens on tap, and the reward, belong to the screen.
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

  static const _closed = _FrameWindow(-1, 0, 0.10, 0.20);
  static const _opening = _FrameWindow(0.10, 0.20, 0.38, 0.46);
  static const _burst = _FrameWindow(0.38, 0.46, 0.72, 0.80);
  static const _opened = _FrameWindow(0.72, 0.80, 9, 10);

  Widget _frame(ChestFrame frame, _FrameWindow window) {
    return Positioned.fill(
      child: Image.asset(
        style.frameAsset(frame),
        opacity: progress.drive(window),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
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
                builder: (context, child) {
                  final t = progress.value;
                  var angle = 0.0;
                  var dx = 0.0;
                  var scale = 1.0;
                  if (!reduceMotion) {
                    // Rattle while the lock gives way, growing then stopping.
                    final rattle = t > 0 && t < 0.24
                        ? math.sin(t * 150) * (t / 0.24)
                        : 0.0;
                    angle = rattle * 0.03;
                    dx = rattle * height * 0.012;
                    // Pop as the energy bursts out.
                    final pop = ((t - 0.40) / 0.30).clamp(0.0, 1.0);
                    scale = 1 + 0.06 * math.sin(pop * math.pi);
                  }
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: Transform.rotate(
                      angle: angle,
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    _frame(ChestFrame.closed, _closed),
                    _frame(ChestFrame.opening, _opening),
                    _frame(ChestFrame.burst, _burst),
                    _frame(ChestFrame.opened, _opened),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
