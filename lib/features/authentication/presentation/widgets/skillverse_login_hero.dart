import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// The interactive student character hero for the SkillVerse Login screen.
///
/// Features:
/// - Isolated character asset (`character_open.png` / `character_closed.png`)
/// - Reacts to Password field focus by closing his eyes ("I won't look at your password")
/// - Re-opens eyes smoothly when Password loses focus
/// - Natural periodic blink (~120ms closed every ~4.5s) when password is NOT focused
/// - Gentle vertical floating (-3px to +4px) and subtle breathing scale (1.00 to 1.012)
/// - Soft cyan + violet ambient glow behind the character
/// - Smooth keyboard collapse preserving full visibility of the character's face
/// - Accessible reduced-motion support
/// - Zero external dependencies or layout shifts.
class SkillverseLoginHero extends StatefulWidget {
  final Animation<double> ambientAnimation;
  final FocusNode? passwordFocusNode;
  final bool isKeyboardVisible;
  final bool reduceMotion;

  const SkillverseLoginHero({
    super.key,
    required this.ambientAnimation,
    this.passwordFocusNode,
    this.isKeyboardVisible = false,
    this.reduceMotion = false,
  });

  static const String assetOpen = 'assets/images/auth/character_open.png';
  static const String assetClosed = 'assets/images/auth/character_closed.png';

  @override
  State<SkillverseLoginHero> createState() => _SkillverseLoginHeroState();
}

class _SkillverseLoginHeroState extends State<SkillverseLoginHero> {
  bool _isPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    widget.passwordFocusNode?.addListener(_handleFocusChange);
    _isPasswordFocused = widget.passwordFocusNode?.hasFocus ?? false;
  }

  @override
  void didUpdateWidget(covariant SkillverseLoginHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passwordFocusNode != widget.passwordFocusNode) {
      oldWidget.passwordFocusNode?.removeListener(_handleFocusChange);
      widget.passwordFocusNode?.addListener(_handleFocusChange);
      _isPasswordFocused = widget.passwordFocusNode?.hasFocus ?? false;
    }
  }

  @override
  void dispose() {
    widget.passwordFocusNode?.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    final hasFocus = widget.passwordFocusNode?.hasFocus ?? false;
    if (_isPasswordFocused != hasFocus && mounted) {
      setState(() {
        _isPasswordFocused = hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Responsive hero height: shrinks when keyboard opens, keeping the face in view
    final double targetHeight = widget.isKeyboardVisible
        ? (screenHeight * 0.16).clamp(115.0, 145.0)
        : (screenHeight < 700
            ? 180.0
            : (screenHeight * 0.28).clamp(195.0, 260.0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: targetHeight,
      child: AnimatedBuilder(
        animation: widget.ambientAnimation,
        builder: (context, _) {
          final t = widget.reduceMotion ? 0.0 : widget.ambientAnimation.value;

          // 1. Idle vertical float: -3.0 to +4.0 px over 3.2s
          final floatY = widget.reduceMotion
              ? 0.0
              : -3.0 + 7.0 * ((math.sin(t * 2 * math.pi) + 1) / 2);

          // 2. Idle breathing scale: 1.000 to 1.012
          final breathScale = widget.reduceMotion
              ? 1.0
              : 1.00 + 0.012 * ((math.cos(t * 2 * math.pi) + 1) / 2);

          // 3. Soft character glow opacity: 0.10 to 0.20
          final glowOpacity = widget.reduceMotion
              ? 0.14
              : 0.10 + 0.10 * ((math.sin(t * 2 * math.pi - math.pi / 2) + 1) / 2);

          // 4. Natural blink logic:
          // If password is focused, eyes are ALWAYS closed.
          // Otherwise, brief blink near the end of the ambient loop (t between 0.965 and 0.990)
          final bool isNaturalBlink =
              !widget.reduceMotion && (t >= 0.965 && t <= 0.990);
          final bool eyesClosed = _isPasswordFocused || isNaturalBlink;

          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.scale(
              scale: breathScale,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Soft cyan + violet ambient radial aura behind character
                  Positioned(
                    top: targetHeight * 0.15,
                    child: Container(
                      width: 220,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.gemCyan.withValues(alpha: glowOpacity * 0.8),
                            AppColors.violet.withValues(alpha: glowOpacity * 0.9),
                            AppColors.primary.withValues(alpha: glowOpacity * 0.4),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Interactive Character Asset with smooth eye state transition
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutQuad,
                    switchOutCurve: Curves.easeInQuad,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.985, end: 1.0)
                              .animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      eyesClosed
                          ? SkillverseLoginHero.assetClosed
                          : SkillverseLoginHero.assetOpen,
                      key: ValueKey<bool>(eyesClosed),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
