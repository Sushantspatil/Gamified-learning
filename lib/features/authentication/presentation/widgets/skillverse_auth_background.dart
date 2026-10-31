import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';

enum AuthParticleShape { circle, sparkle }

class _AuthParticleSpec {
  final double xRatio;
  final double yBaseRatio;
  final double radius;
  final double speed;
  final double phase;
  final Color color;
  final AuthParticleShape shape;

  const _AuthParticleSpec({
    required this.xRatio,
    required this.yBaseRatio,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
    this.shape = AuthParticleShape.circle,
  });
}

/// 12 deterministic lightweight cosmic magic particles and subtle sparkles.
/// Kept under the 15-particle limit for 60/90/120 Hz efficiency.
const List<_AuthParticleSpec> _kCosmicParticles = [
  // Upper sky & floating castle region
  _AuthParticleSpec(
    xRatio: 0.18,
    yBaseRatio: 0.12,
    radius: 2.2,
    speed: 0.85,
    phase: 0.10,
    color: AppColors.gemCyan,
    shape: AuthParticleShape.sparkle,
  ),
  _AuthParticleSpec(
    xRatio: 0.82,
    yBaseRatio: 0.14,
    radius: 2.5,
    speed: 0.95,
    phase: 0.40,
    color: AppColors.violet,
    shape: AuthParticleShape.circle,
  ),
  _AuthParticleSpec(
    xRatio: 0.50,
    yBaseRatio: 0.08,
    radius: 1.8,
    speed: 0.70,
    phase: 0.75,
    color: AppColors.primary,
    shape: AuthParticleShape.sparkle,
  ),

  // Mid region (hero & floating gamified badges)
  _AuthParticleSpec(
    xRatio: 0.12,
    yBaseRatio: 0.32,
    radius: 2.8,
    speed: 1.05,
    phase: 0.20,
    color: AppColors.coinGold,
    shape: AuthParticleShape.sparkle,
  ),
  _AuthParticleSpec(
    xRatio: 0.88,
    yBaseRatio: 0.30,
    radius: 3.0,
    speed: 0.80,
    phase: 0.60,
    color: AppColors.gemCyan,
    shape: AuthParticleShape.circle,
  ),
  _AuthParticleSpec(
    xRatio: 0.28,
    yBaseRatio: 0.45,
    radius: 2.0,
    speed: 1.10,
    phase: 0.30,
    color: AppColors.primaryLight,
    shape: AuthParticleShape.circle,
  ),
  _AuthParticleSpec(
    xRatio: 0.74,
    yBaseRatio: 0.48,
    radius: 2.4,
    speed: 0.90,
    phase: 0.85,
    color: AppColors.coinGold,
    shape: AuthParticleShape.sparkle,
  ),

  // Lower cosmic form / planetary glow region
  _AuthParticleSpec(
    xRatio: 0.08,
    yBaseRatio: 0.72,
    radius: 3.2,
    speed: 0.75,
    phase: 0.15,
    color: AppColors.gemCyan,
    shape: AuthParticleShape.sparkle,
  ),
  _AuthParticleSpec(
    xRatio: 0.92,
    yBaseRatio: 0.76,
    radius: 2.6,
    speed: 1.15,
    phase: 0.55,
    color: AppColors.violet,
    shape: AuthParticleShape.circle,
  ),
  _AuthParticleSpec(
    xRatio: 0.22,
    yBaseRatio: 0.88,
    radius: 2.0,
    speed: 0.80,
    phase: 0.35,
    color: AppColors.primaryLight,
    shape: AuthParticleShape.sparkle,
  ),
  _AuthParticleSpec(
    xRatio: 0.80,
    yBaseRatio: 0.86,
    radius: 2.8,
    speed: 0.95,
    phase: 0.65,
    color: AppColors.gemCyan,
    shape: AuthParticleShape.circle,
  ),
  _AuthParticleSpec(
    xRatio: 0.52,
    yBaseRatio: 0.92,
    radius: 2.2,
    speed: 1.00,
    phase: 0.90,
    color: AppColors.primary,
    shape: AuthParticleShape.circle,
  ),
];

class _AuthParticlesPainter extends CustomPainter {
  final double animationProgress;
  final bool isDark;

  _AuthParticlesPainter({
    required this.animationProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _kCosmicParticles) {
      final cycle = (animationProgress * p.speed + p.phase) % 1.0;

      // Vertical drift: upward 30px
      const verticalTravel = 30.0;
      final y = (p.yBaseRatio * size.height) - (cycle * verticalTravel);

      // Horizontal slight wobble (-5px to +5px)
      final x = p.xRatio * size.width + math.sin(cycle * math.pi * 2) * 5.0;

      // Alpha breathing curve (0.0 -> peak -> 0.0)
      final alpha = (math.sin(cycle * math.pi) * 0.85).clamp(0.0, 1.0);
      if (alpha <= 0.03) continue;

      if (p.shape == AuthParticleShape.sparkle) {
        _drawSparkle(canvas, Offset(x, y), p.radius, p.color, alpha);
      } else {
        _drawGlowCircle(canvas, Offset(x, y), p.radius, p.color, alpha);
      }
    }
  }

  void _drawGlowCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    // Soft outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * (isDark ? 0.35 : 0.22))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(center, radius * 1.8, glowPaint);

    // Core
    final corePaint = Paint()..color = color.withValues(alpha: alpha * 0.90);
    canvas.drawCircle(center, radius, corePaint);

    // Bright center
    final centerPaint = Paint()
      ..color = (isDark ? Colors.white : color).withValues(alpha: alpha * 0.85);
    canvas.drawCircle(center, radius * 0.4, centerPaint);
  }

  void _drawSparkle(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double alpha,
  ) {
    final arm = size * 1.6;

    final linePaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.85)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      linePaint,
    );

    final corePaint = Paint()
      ..color = (isDark ? Colors.white : color).withValues(alpha: alpha * 0.95);
    canvas.drawCircle(center, size * 0.5, corePaint);
  }

  @override
  bool shouldRepaint(covariant _AuthParticlesPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.isDark != isDark;
  }
}

/// Cosmic background with animated glow orbs, distant planetary curves, and floating particles.
class SkillverseAuthBackground extends StatelessWidget {
  final Animation<double> ambientAnimation;
  final bool reduceMotion;

  const SkillverseAuthBackground({
    super.key,
    required this.ambientAnimation,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Theme-aware base background
          DecoratedBox(decoration: BoxDecoration(color: colors.background)),

          // 2. Animated gradient glow orbs
          AnimatedBuilder(
            animation: ambientAnimation,
            builder: (context, _) {
              final t = reduceMotion ? 0.5 : ambientAnimation.value;
              final sinT = math.sin(t * 2 * math.pi);
              final cosT = math.cos(t * 2 * math.pi);

              final orbMultiplier = isDark ? 1.0 : 0.65;

              // Orb 1: Upper-left violet/purple glow
              final orb1Scale = 0.95 + 0.12 * ((sinT + 1) / 2);
              final orb1Opacity =
                  (0.08 + 0.05 * ((cosT + 1) / 2)) * orbMultiplier;
              final orb1Offset = Offset(-20 + 12 * cosT, -30 + 10 * sinT);

              // Orb 2: Upper-right cyan/blue glow
              final orb2Scale = 0.96 + 0.10 * ((cosT + 1) / 2);
              final orb2Opacity =
                  (0.07 + 0.05 * ((sinT + 1) / 2)) * orbMultiplier;
              final orb2Offset = Offset(20 - 10 * sinT, -10 + 12 * cosT);

              // Orb 3: Lower-center magenta/violet horizon glow
              final orb3Scale = 0.98 + 0.08 * ((sinT + 1) / 2);
              final orb3Opacity =
                  (0.09 + 0.05 * ((cosT + 1) / 2)) * orbMultiplier;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Upper-left orb
                  Positioned(
                    top: orb1Offset.dy,
                    left: orb1Offset.dx,
                    width: 320,
                    height: 320,
                    child: Transform.scale(
                      scale: orb1Scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.primary.withValues(alpha: orb1Opacity),
                              colors.violet.withValues(
                                alpha: orb1Opacity * 0.5,
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Upper-right orb
                  Positioned(
                    top: orb2Offset.dy,
                    right: orb2Offset.dx,
                    width: 300,
                    height: 300,
                    child: Transform.scale(
                      scale: orb2Scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.secondary.withValues(alpha: orb2Opacity),
                              AppColors.gemCyan.withValues(
                                alpha: orb2Opacity * 0.4,
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.50, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom planetary curves and glowing horizon
                  Positioned(
                    bottom: -140,
                    left: -80,
                    right: -80,
                    height: 380,
                    child: Transform.scale(
                      scale: orb3Scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.primaryDark.withValues(
                                alpha: orb3Opacity * 1.5,
                              ),
                              colors.violet.withValues(alpha: orb3Opacity),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Planetary rim edge highlights on bottom corners
                  Positioned(
                    bottom: -60,
                    left: -40,
                    width: 220,
                    height: 220,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.gemCyan.withValues(
                              alpha: isDark ? 0.12 : 0.08,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.70],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -70,
                    right: -40,
                    width: 240,
                    height: 240,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colors.violet.withValues(
                              alpha: isDark ? 0.12 : 0.08,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.70],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Ambient magical particles overlay
          if (!reduceMotion)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: ambientAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _AuthParticlesPainter(
                      animationProgress: ambientAnimation.value,
                      isDark: isDark,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
