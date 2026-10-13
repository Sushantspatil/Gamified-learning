import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class _MagicRingPainter extends CustomPainter {
  final double rotationAngle;

  _MagicRingPainter({required this.rotationAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.90,
      height: size.height * 0.50,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.18); // Natural celestial tilt
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);

    // Glowing orbital sweep gradient
    final gradient = SweepGradient(
      colors: [
        AppColors.gemCyan.withValues(alpha: 0.0),
        AppColors.gemCyan.withValues(alpha: 0.45),
        AppColors.violet.withValues(alpha: 0.65),
        AppColors.primary.withValues(alpha: 0.40),
        AppColors.gemCyan.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.35, 0.65, 0.85, 1.0],
    );

    final ringPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.drawOval(rect, ringPaint);

    final thinPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawOval(rect, thinPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MagicRingPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle;
  }
}

/// The upper magical student character hero with animated glowing book,
/// rotating orbital ring, and floating motion.
class SkillverseLoginHero extends StatelessWidget {
  final Animation<double> ambientAnimation;
  final bool isKeyboardVisible;
  final bool reduceMotion;

  const SkillverseLoginHero({
    super.key,
    required this.ambientAnimation,
    this.isKeyboardVisible = false,
    this.reduceMotion = false,
  });

  static const String _artworkPath = 'assets/images/splash/skillverse_splash.png';

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Responsive hero height based on keyboard state and screen size
    final double targetHeight = isKeyboardVisible
        ? 0.0 // Smoothly collapse when keyboard opens to preserve maximum form area
        : (screenHeight < 700 ? 175.0 : (screenHeight * 0.36).clamp(220.0, 340.0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: targetHeight,
      width: screenWidth.clamp(0.0, 480.0),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: 520,
          child: AnimatedBuilder(
            animation: ambientAnimation,
            builder: (context, child) {
              final t = reduceMotion ? 0.0 : ambientAnimation.value;

              // 1. Vertical float (-4px to +5px) over 3.2s
              final floatY = reduceMotion
                  ? 0.0
                  : -4.0 + 9.0 * ((math.sin(t * 2 * math.pi) + 1) / 2);

              // 2. Breathing scale (1.00 to 1.015)
              final breathScale = reduceMotion
                  ? 1.0
                  : 1.00 + 0.015 * ((math.cos(t * 2 * math.pi) + 1) / 2);

              // 3. Book glow pulse (0.10 to 0.28)
              final bookGlowOpacity = reduceMotion
                  ? 0.16
                  : 0.10 + 0.18 * ((math.sin(t * 4 * math.pi) + 1) / 2);

              // 4. Rotating magic ring
              final ringAngle = reduceMotion ? 0.0 : t * 2 * math.pi;

              return Transform.translate(
                offset: Offset(0, floatY),
                child: Transform.scale(
                  scale: breathScale,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow layer 1: Behind character book glow
                      Positioned(
                        top: 130,
                        child: Transform.scale(
                          scale: 0.95 + 0.10 * (bookGlowOpacity / 0.28),
                          child: Container(
                            width: 240,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.coinGold
                                      .withValues(alpha: bookGlowOpacity * 0.7),
                                  AppColors.gemCyan
                                      .withValues(alpha: bookGlowOpacity * 0.9),
                                  AppColors.violet
                                      .withValues(alpha: bookGlowOpacity * 0.6),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35, 0.65, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Glow layer 2: Magic orbital ring
                      if (!reduceMotion)
                        Positioned(
                          top: 100,
                          width: 290,
                          height: 160,
                          child: CustomPaint(
                            painter: _MagicRingPainter(rotationAngle: ringAngle),
                          ),
                        ),

                      // Main Artwork with smooth seamless gradient fade at bottom
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.72, 0.98],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          _artworkPath,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
