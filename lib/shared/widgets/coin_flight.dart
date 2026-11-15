import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';
import 'coin_burst_painter.dart';

/// Makes coins fly from the middle of one widget to the middle of another (a
/// reward flying into the coin counter), on top of everything else.
///
/// [from] and [to] are the keys of the two widgets. Nothing happens, and null is
/// returned, when either is not on screen, when it has no size, or when the
/// player prefers reduced motion. Otherwise the returned entry removes itself
/// when the flight ends; call `remove()` on it to cut the flight short (for
/// example when the screen is left).
OverlayEntry? flyCoins(
  BuildContext context, {
  required GlobalKey from,
  required GlobalKey to,
  int count = 10,
  Duration duration = const Duration(milliseconds: 1400),
}) {
  if (AppMotion.reduceMotion(context)) return null;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final overlayBox = overlay?.context.findRenderObject();
  final fromBox = from.currentContext?.findRenderObject();
  final toBox = to.currentContext?.findRenderObject();
  if (overlay == null ||
      overlayBox is! RenderBox ||
      fromBox is! RenderBox ||
      toBox is! RenderBox ||
      !fromBox.attached ||
      !toBox.attached ||
      fromBox.size.isEmpty ||
      toBox.size.isEmpty) {
    return null;
  }

  Offset centreOf(RenderBox box) =>
      overlayBox.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => CoinFlight(
      key: const Key('coin_flight'),
      from: centreOf(fromBox),
      to: centreOf(toBox),
      count: count,
      duration: duration,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  return entry;
}

/// The coins of one flight. Use [flyCoins] rather than this directly.
class CoinFlight extends StatefulWidget {
  final Offset from;
  final Offset to;
  final int count;
  final Duration duration;
  final VoidCallback onDone;

  const CoinFlight({
    super.key,
    required this.from,
    required this.to,
    required this.count,
    required this.duration,
    required this.onDone,
  });

  @override
  State<CoinFlight> createState() => _CoinFlightState();
}

class _CoinFlightState extends State<CoinFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: CoinBurstPainter(
            progress: _controller,
            from: widget.from,
            to: widget.to,
            coinCount: widget.count,
          ),
        ),
      ),
    );
  }
}
