import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';

/// Glowing primary gradient button with press bounce, loading spinner, and subtle audio feedback.
class AnimatedLoginButton extends ConsumerStatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final Animation<double> ambientAnimation;
  final bool reduceMotion;

  const AnimatedLoginButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    required this.ambientAnimation,
    this.reduceMotion = false,
  });

  @override
  ConsumerState<AnimatedLoginButton> createState() => _AnimatedLoginButtonState();
}

class _AnimatedLoginButtonState extends ConsumerState<AnimatedLoginButton> {
  bool _isPressed = false;

  void _handleTapDown(_) {
    if (widget.isLoading || widget.onPressed == null) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(_) {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _handleClick() {
    if (widget.isLoading || widget.onPressed == null) return;

    // Subtle audio tap feedback via existing GameAudioService
    try {
      ref.read(gameAudioServiceProvider).play(GameSound.buttonTap);
    } catch (_) {
      // Audio service non-fatal fallback
    }

    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool canPress = !widget.isLoading && widget.onPressed != null;

    return AnimatedBuilder(
      animation: widget.ambientAnimation,
      builder: (context, _) {
        final t = widget.reduceMotion ? 0.5 : widget.ambientAnimation.value;
        // Glow pulse: 0.15 -> 0.30 when idle, minimal when loading
        final glowOpacity = (widget.isLoading || widget.reduceMotion)
            ? 0.08
            : 0.15 + 0.15 * ((1 + math.sin(t * 2 * math.pi)) / 2);

        return GestureDetector(
          onTapDown: canPress ? _handleTapDown : null,
          onTapUp: canPress ? _handleTapUp : null,
          onTapCancel: _handleTapCancel,
          onTap: canPress ? _handleClick : null,
          child: AnimatedScale(
            scale: _isPressed && !widget.reduceMotion ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6D5DFE),
                    Color(0xFF8A63FF),
                    Color(0xFFB052FF),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A63FF).withValues(alpha: glowOpacity),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.gemCyan.withValues(alpha: glowOpacity * 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.isLoading
                        ? Row(
                            key: const ValueKey('loading'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Logging in...',
                                style: AppTypography.button.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('idle'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Log In',
                                style: AppTypography.button.copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
