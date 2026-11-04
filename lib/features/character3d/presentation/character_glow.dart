import 'package:flutter/material.dart';

import '../../../app/motion/app_motion.dart';
import '../../../app/theme/app_theme_colors.dart';

/// A soft coloured glow behind the character, so it stands out from the card
/// it sits on. It follows the theme (stronger on dark cards, gentler on light
/// ones), and breathes very slowly unless the player prefers reduced motion.
///
/// Wrap the character: `CharacterGlow(child: Character3dView(...))`. The glow
/// is painted beneath the child and never takes touches.
class CharacterGlow extends StatefulWidget {
  final Widget child;

  /// Defaults to the theme's primary colour; pass a frame colour to match what
  /// the player has equipped.
  final Color? color;

  /// 1 is the normal strength.
  final double strength;

  /// Where the glow is centred inside the box.
  final Alignment alignment;

  /// Size of the glow as a fraction of the box's shorter side.
  final double radius;

  const CharacterGlow({
    super.key,
    required this.child,
    this.color,
    this.strength = 1,
    this.alignment = const Alignment(0, 0.15),
    this.radius = 0.62,
  });

  /// A low pool of light on the floor, for a wide strip the character walks along.
  const CharacterGlow.floor({
    super.key,
    required this.child,
    this.color,
    this.strength = 1,
  }) : alignment = const Alignment(0, 0.9),
       radius = 0.55;

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
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                final k = 0.8 + 0.2 * Curves.easeInOut.transform(_breath.value);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: widget.alignment,
                      radius: widget.radius,
                      colors: [
                        base.withValues(alpha: peak * k),
                        base.withValues(alpha: peak * k * 0.35),
                        base.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
