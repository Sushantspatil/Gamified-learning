import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class _ParticleData {
  final double xRatio; // 0.0 to 1.0
  final double yBaseRatio; // 0.0 to 1.0
  final double radius;
  final double speed;
  final double phase;
  final Color color;

  const _ParticleData({
    required this.xRatio,
    required this.yBaseRatio,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
  });
}

/// 12 curated glowing particles floating gently around the magical world.
const List<_ParticleData> _kSplashParticles = [
  _ParticleData(
    xRatio: 0.18,
    yBaseRatio: 0.62,
    radius: 3.2,
    speed: 0.8,
    phase: 0.1,
    color: AppColors.gemCyan,
  ),
  _ParticleData(
    xRatio: 0.28,
    yBaseRatio: 0.75,
    radius: 2.2,
    speed: 1.1,
    phase: 0.45,
    color: AppColors.primary,
  ),
  _ParticleData(
    xRatio: 0.82,
    yBaseRatio: 0.68,
    radius: 3.5,
    speed: 0.9,
    phase: 0.25,
    color: AppColors.violet,
  ),
  _ParticleData(
    xRatio: 0.72,
    yBaseRatio: 0.54,
    radius: 2.5,
    speed: 1.2,
    phase: 0.7,
    color: AppColors.coinGold,
  ),
  _ParticleData(
    xRatio: 0.38,
    yBaseRatio: 0.48,
    radius: 3.0,
    speed: 0.7,
    phase: 0.3,
    color: AppColors.gemCyan,
  ),
  _ParticleData(
    xRatio: 0.62,
    yBaseRatio: 0.42,
    radius: 2.0,
    speed: 1.0,
    phase: 0.85,
    color: AppColors.coinGold,
  ),
  _ParticleData(
    xRatio: 0.15,
    yBaseRatio: 0.45,
    radius: 2.8,
    speed: 0.95,
    phase: 0.6,
    color: AppColors.violet,
  ),
  _ParticleData(
    xRatio: 0.88,
    yBaseRatio: 0.40,
    radius: 2.4,
    speed: 0.85,
    phase: 0.15,
    color: AppColors.gemCyan,
  ),
  _ParticleData(
    xRatio: 0.50,
    yBaseRatio: 0.72,
    radius: 3.4,
    speed: 1.0,
    phase: 0.9,
    color: AppColors.gemCyan,
  ),
  _ParticleData(
    xRatio: 0.32,
    yBaseRatio: 0.32,
    radius: 2.2,
    speed: 0.75,
    phase: 0.4,
    color: AppColors.coinGold,
  ),
  _ParticleData(
    xRatio: 0.78,
    yBaseRatio: 0.30,
    radius: 3.0,
    speed: 1.15,
    phase: 0.55,
    color: AppColors.primary,
  ),
  _ParticleData(
    xRatio: 0.45,
    yBaseRatio: 0.25,
    radius: 2.6,
    speed: 0.8,
    phase: 0.05,
    color: AppColors.violet,
  ),
];

class SplashParticlesPainter extends CustomPainter {
  final double animationValue;

  SplashParticlesPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _kSplashParticles) {
      // Gentle vertical float upward (30 - 55 pixels)
      final cycle = (animationValue * p.speed + p.phase) % 1.0;
      final verticalTravel = 48.0;
      final y = (p.yBaseRatio * size.height) - (cycle * verticalTravel);
      final x = p.xRatio * size.width + math.sin(cycle * math.pi * 2) * 5.0;

      // Soft alpha breathing (fade in, peak, fade out)
      final alpha = (math.sin(cycle * math.pi) * 0.75).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      // Outer glow
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(x, y), p.radius * 2.0, glowPaint);

      // Core particle
      final corePaint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(x, y), p.radius, corePaint);

      // Bright pinpoint center
      final centerPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.85);
      canvas.drawCircle(Offset(x, y), p.radius * 0.45, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SplashParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class SplashParticlesOverlay extends StatelessWidget {
  final Animation<double> animation;

  const SplashParticlesOverlay({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return CustomPaint(
            painter: SplashParticlesPainter(
              animationValue: animation.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}
