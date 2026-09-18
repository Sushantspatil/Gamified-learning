import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';

class QuizCelebrationOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const QuizCelebrationOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<QuizCelebrationOverlay> createState() => _QuizCelebrationOverlayState();
}

class _QuizCelebrationOverlayState extends State<QuizCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _particles = _buildParticles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasPlayed || !widget.enabled) return;
      if (AppMotion.reduceMotion(context)) return;
      _hasPlayed = true;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _QuizCelebrationPainter(
                    colors: context.themeColors,
                    particles: _particles,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<_ConfettiParticle> _buildParticles() {
    final colors = [
      AppColors.xpPurple,
      AppColors.coinGold,
      const Color(0xFF39D5FF),
      const Color(0xFF9B7CFF),
      const Color(0xFFFF6FAE),
    ];
    final particles = <_ConfettiParticle>[];

    for (var side = 0; side < 2; side++) {
      final direction = side == 0 ? 1.0 : -1.0;
      for (var index = 0; index < 18; index++) {
        final spread = -0.94 + (index / 17) * 1.22;
        final force = 0.42 + (index % 6) * 0.045;
        particles.add(
          _ConfettiParticle(
            side: side == 0 ? _BurstSide.left : _BurstSide.right,
            angle: spread * direction,
            force: force,
            color: colors[(index + side * 2) % colors.length],
            size: 5.0 + (index % 4) * 1.5,
            spin: (index.isEven ? 1 : -1) * (0.7 + index * 0.04),
            delay: (index % 5) * 0.025,
          ),
        );
      }
    }

    return particles;
  }
}

class _QuizCelebrationPainter extends CustomPainter {
  final AppThemeColors colors;
  final List<_ConfettiParticle> particles;
  final double progress;

  const _QuizCelebrationPainter({
    required this.colors,
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    for (final particle in particles) {
      final localProgress = ((progress - particle.delay) / (1 - particle.delay))
          .clamp(0.0, 1.0)
          .toDouble();
      if (localProgress <= 0) continue;

      final eased = Curves.easeOutCubic.transform(localProgress);
      final fade = (1 - Curves.easeInCubic.transform(localProgress))
          .clamp(0.0, 1.0)
          .toDouble();
      final origin = Offset(
        particle.side == _BurstSide.left
            ? size.width * 0.08
            : size.width * 0.92,
        size.height * 0.72,
      );
      final horizontalDirection = particle.side == _BurstSide.left ? 1.0 : -1.0;
      final travel = size.shortestSide * particle.force;
      final x = math.cos(particle.angle) * travel * eased * horizontalDirection;
      final y =
          -math.sin(particle.angle.abs() + 0.28) * travel * eased +
          size.height * 0.22 * localProgress * localProgress;
      final center = origin + Offset(x, y);

      final paint = Paint()
        ..color = particle.color.withValues(alpha: 0.88 * fade)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(progress * math.pi * particle.spin);

      if (particle.size.round().isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size * 1.55,
              height: particle.size,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, particle.size * 0.5, paint);
      }

      canvas.restore();
    }

    _paintPopper(canvas, size, _BurstSide.left);
    _paintPopper(canvas, size, _BurstSide.right);
  }

  void _paintPopper(Canvas canvas, Size size, _BurstSide side) {
    final localProgress = (progress / 0.42).clamp(0.0, 1.0).toDouble();
    final fade = (1 - progress).clamp(0.0, 1.0).toDouble();
    if (fade <= 0) return;

    final origin = Offset(
      side == _BurstSide.left ? size.width * 0.06 : size.width * 0.94,
      size.height * 0.73,
    );
    final direction = side == _BurstSide.left ? -0.65 : 0.65;
    final paint = Paint()
      ..color = colors.warning.withValues(alpha: 0.34 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(direction);

    for (var ray = 0; ray < 4; ray++) {
      final angle = -0.42 + ray * 0.28;
      final length = 20.0 + ray * 4;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * length, -math.sin(angle) * length) *
            localProgress,
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_QuizCelebrationPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.particles != particles ||
        oldDelegate.progress != progress;
  }
}

enum _BurstSide { left, right }

class _ConfettiParticle {
  final _BurstSide side;
  final double angle;
  final double force;
  final Color color;
  final double size;
  final double spin;
  final double delay;

  const _ConfettiParticle({
    required this.side,
    required this.angle,
    required this.force,
    required this.color,
    required this.size,
    required this.spin,
    required this.delay,
  });
}
