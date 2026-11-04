import 'package:flutter/material.dart';

import '../../../app/motion/app_motion.dart';
import '../../../app/theme/app_theme_colors.dart';

/// A soft coloured glow behind the character, so it stands out from the card
/// it sits on. It follows the theme (stronger on dark cards, gentler on light
/// ones), and breathes very slowly unless the player prefers reduced motion.
///
/// The light is an ellipse that fades to nothing before it reaches the edge of
/// the box it is given, so it never ends in a straight edge. Wrap the character:
/// `CharacterGlow(child: Character3dView(...))`. It never takes touches.
class CharacterGlow extends StatefulWidget {
  final Widget child;

  /// Defaults to the theme's primary colour; pass a frame colour to match what
  /// the player has equipped.
  final Color? color;

  /// 1 is the normal strength.
  final double strength;

  /// Where the glow is centred, as a fraction of the box (0.5, 0.5 = middle).
  final Offset center;

  /// Half-width and half-height of the light, as a fraction of the box.
  final Size reach;

  const CharacterGlow({
    super.key,
    required this.child,
    this.color,
    this.strength = 1,
    this.center = const Offset(0.5, 0.56),
    this.reach = const Size(0.46, 0.46),
  });

  /// A low pool of light on the floor, for a wide strip the character walks along.
  const CharacterGlow.floor({
    super.key,
    required this.child,
    this.color,
    this.strength = 1,
  }) : center = const Offset(0.5, 0.8),
       reach = const Size(0.34, 0.2);

  @override
  State<CharacterGlow> createState() => _CharacterGlowState();
}

class _CharacterGlowState extends State<CharacterGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A ticker that is muted while the screen is covered also pauses this.
    if (AppMotion.reduceMotion(context)) {
      _breath.stop();
      _breath.value = 1;
    } else if (!_breath.isAnimating) {
      // Bounded, so a screen that is left open settles (and tests can finish).
      _breath.repeat(reverse: true, count: 12);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.color ?? context.themeColors.primary;
    final peak = (dark ? 0.38 : 0.22) * widget.strength;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, _) {
                  final k =
                      0.8 + 0.2 * Curves.easeInOut.transform(_breath.value);
                  return CustomPaint(
                    key: const Key('character_glow_light'),
                    painter: GlowPainter(
                      color: base,
                      peakAlpha: peak * k,
                      center: widget.center,
                      reach: widget.reach,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Paints the glow: a radial gradient squeezed into an ellipse that lies wholly
/// inside the box, fading to fully transparent at its rim.
class GlowPainter extends CustomPainter {
  final Color color;
  final double peakAlpha;
  final Offset center;
  final Size reach;

  const GlowPainter({
    required this.color,
    required this.peakAlpha,
    required this.center,
    required this.reach,
  });

  /// The ellipse the light covers, clamped to stay inside [size].
  static Rect lightRect(Size size, Offset center, Size reach) {
    final rx = (reach.width * size.width).clamp(0.0, size.width / 2);
    final ry = (reach.height * size.height).clamp(0.0, size.height / 2);
    final cx = (center.dx * size.width).clamp(rx, size.width - rx);
    final cy = (center.dy * size.height).clamp(ry, size.height - ry);
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || peakAlpha <= 0) return;
    final rect = lightRect(size, center, reach);
    if (rect.isEmpty) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: peakAlpha),
          color.withValues(alpha: peakAlpha * 0.4),
          color.withValues(alpha: peakAlpha * 0.1),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 0.78, 1],
      ).createShader(rect);
    // drawOval fills the whole rect; the gradient is already transparent at
    // its rim, so there is no visible edge.
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(GlowPainter old) =>
      old.color != color ||
      old.peakAlpha != peakAlpha ||
      old.center != center ||
      old.reach != reach;
}
