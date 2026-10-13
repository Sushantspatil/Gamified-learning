import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

enum ParticleShape { circle, sparkle }

class _ParticleSpec {
  final double xRatio; // 0.0 to 1.0 (screen width)
  final double yBaseRatio; // 0.0 to 1.0 (screen height)
  final double radius;
  final double speed;
  final double phase;
  final Color color;
  final ParticleShape shape;

  const _ParticleSpec({
    required this.xRatio,
    required this.yBaseRatio,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
    this.shape = ParticleShape.circle,
  });
}

/// 11 deterministic floating magic particles and subtle ambient sparkles.
/// Kept under the 15-particle limit for 60/90/120 Hz efficiency.
const List<_ParticleSpec> _kDeterministicParticles = [
  // Floating around the central character & glowing book
  _ParticleSpec(
    xRatio: 0.22,
    yBaseRatio: 0.60,
    radius: 3.2,
    speed: 0.85,
    phase: 0.1,
    color: AppColors.gemCyan,
    shape: ParticleShape.circle,
  ),
  _ParticleSpec(
    xRatio: 0.78,
    yBaseRatio: 0.65,
    radius: 3.0,
    speed: 0.95,
    phase: 0.35,
    color: AppColors.violet,
    shape: ParticleShape.sparkle,
  ),
  _ParticleSpec(
    xRatio: 0.50,
    yBaseRatio: 0.68,
    radius: 3.4,
    speed: 1.05,
    phase: 0.75,
    color: AppColors.gemCyan,
    shape: ParticleShape.circle,
  ),
  _ParticleSpec(
    xRatio: 0.35,
    yBaseRatio: 0.48,
    radius: 2.5,
    speed: 0.75,
    phase: 0.25,
    color: AppColors.coinGold,
    shape: ParticleShape.sparkle,
  ),
  _ParticleSpec(
    xRatio: 0.65,
    yBaseRatio: 0.52,
    radius: 2.2,
    speed: 1.10,
    phase: 0.60,
    color: AppColors.coinGold,
    shape: ParticleShape.circle,
  ),

  // Ambient sparkles near the gamification elements (Trophy, Gem, Quiz card)
  _ParticleSpec(
    xRatio: 0.24,
    yBaseRatio: 0.34, // Near Trophy
    radius: 2.8,
    speed: 0.70,
    phase: 0.45,
    color: AppColors.coinGold,
    shape: ParticleShape.sparkle,
  ),
  _ParticleSpec(
    xRatio: 0.76,
    yBaseRatio: 0.32, // Near Purple Gem
    radius: 3.2,
    speed: 0.80,
    phase: 0.15,
    color: AppColors.violet,
    shape: ParticleShape.sparkle,
  ),
  _ParticleSpec(
    xRatio: 0.16,
    yBaseRatio: 0.46, // Near Quiz Card
    radius: 2.4,
    speed: 0.90,
    phase: 0.85,
    color: AppColors.gemCyan,
    shape: ParticleShape.circle,
  ),
  _ParticleSpec(
    xRatio: 0.84,
    yBaseRatio: 0.42, // Near Lightning / Stats
    radius: 2.6,
    speed: 1.15,
    phase: 0.50,
    color: AppColors.primary,
    shape: ParticleShape.sparkle,
  ),

  // Subtle upper floating islands atmosphere
  _ParticleSpec(
    xRatio: 0.32,
    yBaseRatio: 0.24,
    radius: 2.0,
    speed: 0.80,
    phase: 0.30,
    color: Colors.white,
    shape: ParticleShape.circle,
  ),
  _ParticleSpec(
    xRatio: 0.68,
    yBaseRatio: 0.22,
    radius: 2.2,
    speed: 0.90,
    phase: 0.70,
    color: AppColors.gemCyan,
    shape: ParticleShape.sparkle,
  ),
];

class SplashParticlesPainter extends CustomPainter {
  final double animationProgress; // 0.0 to 1.0 (continuous time-driven)

  SplashParticlesPainter({required this.animationProgress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _kDeterministicParticles) {
      final cycle = (animationProgress * p.speed + p.phase) % 1.0;

      // Vertical drift: upward 35px from base position
      const verticalTravel = 35.0;
      final y = (p.yBaseRatio * size.height) - (cycle * verticalTravel);

      // Horizontal subtle wobble (-4px to +4px)
      final x = p.xRatio * size.width + math.sin(cycle * math.pi * 2) * 4.0;

      // Soft alpha breathing (fade in, peak, fade out)
      final alpha = (math.sin(cycle * math.pi) * 0.85).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      if (p.shape == ParticleShape.sparkle) {
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
      ..color = color.withValues(alpha: alpha * 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(center, radius * 1.8, glowPaint);

    // Core body
    final corePaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.90);
    canvas.drawCircle(center, radius, corePaint);

    // Pinpoint center
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha * 0.80);
    canvas.drawCircle(center, radius * 0.45, centerPaint);
  }

  void _drawSparkle(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double alpha,
  ) {
    final arm = size * 1.5;

    // Cross arms
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

    // Glowing core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha * 0.95);
    canvas.drawCircle(center, size * 0.55, corePaint);
  }

  @override
  bool shouldRepaint(covariant SplashParticlesPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress;
  }
}

class SplashParticlesOverlay extends StatelessWidget {
  final double animationProgress;

  const SplashParticlesOverlay({
    super.key,
    required this.animationProgress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: SplashParticlesPainter(
          animationProgress: animationProgress,
        ),
        size: Size.infinite,
      ),
    );
  }
}
