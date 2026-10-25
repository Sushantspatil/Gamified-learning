import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';

/// The celebratory presentation style for the end of a game session.
enum CelebrationType {
  /// Standard victory celebration for completed runs with multiple staggered bursts.
  standard,

  /// Spectacular golden-accented celebration with 3 waves for 100% / perfect runs.
  perfect,

  /// Atmospheric, respectful transition for unsuccessful Sudden Death, wrong-answer,
  /// or timeout endings. Avoids misleading victory cannons while providing polished visual feedback.
  subdued,
}

/// Shared, high-performance game completion celebration overlay for SkillVerse.
///
/// Features:
/// - Staggered multi-popper confetti bursts from left/right edges and upper corners.
/// - Rich particle mix: flutter rectangles, circles, twist streamers, 5-point stars,
///   4-point diamond sparkles, SkillVerse gem cyan diamonds, and gold coins.
/// - Radial atmospheric glow and smooth scale-and-fade reward card entrance.
/// - Support for standard, perfect-score, and subdued (game over/timeout) modes.
/// - Full Samsung One UI TalkBack compatibility (`accessibleNavigation` does not suppress motion).
/// - Respects explicit `reduceMotion` (Android "Remove animations" setting).
/// - Single-trigger guarantee per session to prevent duplicate bursts on rebuilds.
class GameCelebrationOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final CelebrationType type;
  final Duration? duration;

  const GameCelebrationOverlay({
    super.key,
    required this.child,
    this.enabled = true,
    this.type = CelebrationType.standard,
    this.duration,
  });

  @override
  State<GameCelebrationOverlay> createState() => _GameCelebrationOverlayState();
}

/// 100% backward-compatible alias for existing imports.
typedef QuizCelebrationOverlay = GameCelebrationOverlay;

class _GameCelebrationOverlayState extends State<GameCelebrationOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;
  late final List<_CelebrationParticle> _particles;
  bool _hasPlayed = false;

  Duration get _defaultDuration {
    switch (widget.type) {
      case CelebrationType.perfect:
        return const Duration(milliseconds: 2800);
      case CelebrationType.standard:
        return const Duration(milliseconds: 2400);
      case CelebrationType.subdued:
        return const Duration(milliseconds: 1600);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? _defaultDuration,
    );

    // Tasteful reward area entrance: scale 0.94 -> 1.0, fade 0.65 -> 1.0
    _entranceScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.22, curve: Curves.easeOutCubic),
      ),
    );
    _entranceOpacity = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
      ),
    );

    _particles = _buildParticles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasPlayed || !widget.enabled) return;
      if (AppMotion.reduceMotion(context)) {
        _hasPlayed = true;
        return;
      }
      _hasPlayed = true;
      _controller.forward();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!AppMotion.reduceMotion(context) &&
          _hasPlayed &&
          !_controller.isCompleted &&
          !_controller.isAnimating) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduceMotion(context);

    if (reduceMotion || !widget.enabled) {
      // With genuine reduced motion requested, render result content immediately
      // without delay, scaling, or explosive particle animations.
      return widget.child;
    }

    return Stack(
      children: [
        // 1. Subtle radial atmospheric glow behind the result card
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  key: const Key('celebration-glow-canvas'),
                  painter: _GlowPainter(
                    colors: context.themeColors,
                    progress: _controller.value,
                    type: widget.type,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Coordinated scale & fade entrance for the reward area
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _entranceOpacity.value,
              child: Transform.scale(
                scale: _entranceScale.value,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),

        // 3. Layered confetti poppers, stars, sparkles, coins, and gems
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  key: const Key('celebration-particles-canvas'),
                  painter: _CelebrationPainter(
                    colors: context.themeColors,
                    particles: _particles,
                    progress: _controller.value,
                    type: widget.type,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_CelebrationParticle> _buildParticles() {
    switch (widget.type) {
      case CelebrationType.subdued:
        return _buildSubduedParticles();
      case CelebrationType.perfect:
        return _buildEnhancedParticles(isPerfect: true);
      case CelebrationType.standard:
        return _buildEnhancedParticles(isPerfect: false);
    }
  }

  /// Gentle, atmospheric floating embers for unsuccessful/timeout game endings.
  List<_CelebrationParticle> _buildSubduedParticles() {
    final particles = <_CelebrationParticle>[];
    final emberColors = [
      const Color(0xFFFF6B6B),
      const Color(0xFFE056FD),
      const Color(0xFFFFBE76),
      const Color(0xFFF8A5C2),
    ];

    for (var i = 0; i < 14; i++) {
      particles.add(
        _CelebrationParticle(
          origin: i.isEven ? _BurstOrigin.bottomLeft : _BurstOrigin.bottomRight,
          shape: _ConfettiShape.ember,
          angle: -0.65 - (i % 5) * 0.12,
          speed: 0.25 + (i % 4) * 0.05,
          color: emberColors[i % emberColors.length],
          size: 3.5 + (i % 3) * 1.5,
          spinSpeed: 0.2 + (i % 3) * 0.1,
          wobbleFrequency: 1.2 + (i % 3) * 0.5,
          delay: (i % 7) * 0.04,
          gravity: -0.15, // Floating gently upward
        ),
      );
    }
    return particles;
  }

  /// Enhanced multi-popper confetti bursts with staggered waves, varied shapes,
  /// and SkillVerse signature palette.
  List<_CelebrationParticle> _buildEnhancedParticles({required bool isPerfect}) {
    final particles = <_CelebrationParticle>[];

    // SkillVerse color constants
    const purple = AppColors.primary; // #6D5DFE
    const violet = AppColors.violet; // #B052FF
    const cyan = AppColors.secondary; // #00B8D9
    const gemCyan = AppColors.gemCyan; // #21E6FF
    const gold = AppColors.coinGold; // #FFB82E
    const white = Colors.white;

    final standardPalette = [
      purple,
      gold,
      cyan,
      violet,
      gemCyan,
      white,
    ];

    final perfectPalette = [
      gold,
      gold,
      gemCyan,
      white,
      violet,
      purple,
    ];

    final palette = isPerfect ? perfectPalette : standardPalette;

    // --- Wave 1: Immediate double popper + upper corner bursts (delay 0.0 -> 0.08) ---
    // Bottom-left & Bottom-right edge cannons
    for (var side = 0; side < 2; side++) {
      final isLeft = side == 0;
      final origin = isLeft ? _BurstOrigin.bottomLeft : _BurstOrigin.bottomRight;
      final count = isPerfect ? 18 : 14;

      for (var i = 0; i < count; i++) {
        // Spread angle: upward-inward arc
        final angle = -0.96 + (i / count) * 0.65;
        final speed = 0.44 + (i % 5) * 0.055;
        final shape = _shapeForIndex(i);
        final color = palette[(i + side * 3) % palette.length];

        particles.add(
          _CelebrationParticle(
            origin: origin,
            shape: shape,
            angle: angle,
            speed: speed,
            color: color,
            size: _sizeForShape(shape, i),
            spinSpeed: (i.isEven ? 1.0 : -1.0) * (0.8 + (i % 4) * 0.35),
            wobbleFrequency: 1.5 + (i % 3) * 0.8,
            delay: (i % 6) * 0.015,
            gravity: 0.68 + (i % 3) * 0.12,
          ),
        );
      }
    }

    // Upper-left & Upper-right corner poppers shooting toward screen center
    for (var side = 0; side < 2; side++) {
      final isLeft = side == 0;
      final origin = isLeft ? _BurstOrigin.topLeft : _BurstOrigin.topRight;
      final count = isPerfect ? 12 : 8;

      for (var i = 0; i < count; i++) {
        // Spread angle: downward-inward arc toward center
        final angle = 0.18 + (i / count) * 0.68;
        final speed = 0.38 + (i % 4) * 0.06;
        final shape = (i % 3 == 0)
            ? _ConfettiShape.star
            : (i % 3 == 1 ? _ConfettiShape.sparkle : _ConfettiShape.rectangle);
        final color = palette[(i + 2 + side * 2) % palette.length];

        particles.add(
          _CelebrationParticle(
            origin: origin,
            shape: shape,
            angle: angle,
            speed: speed,
            color: color,
            size: _sizeForShape(shape, i),
            spinSpeed: (i.isOdd ? 1.0 : -1.0) * (1.1 + (i % 3) * 0.4),
            wobbleFrequency: 1.8 + (i % 2) * 0.6,
            delay: 0.03 + (i % 5) * 0.02,
            gravity: 0.55 + (i % 3) * 0.1,
          ),
        );
      }
    }

    // --- Wave 2: Staggered secondary burst (delay 0.20 -> 0.28) ---
    for (var side = 0; side < 2; side++) {
      final isLeft = side == 0;
      final origin = isLeft ? _BurstOrigin.bottomLeft : _BurstOrigin.bottomRight;
      final count = isPerfect ? 8 : 6;

      for (var i = 0; i < count; i++) {
        final angle = -0.88 + (i / count) * 0.52;
        final speed = 0.48 + (i % 3) * 0.06;
        final shape = (i % 2 == 0)
            ? _ConfettiShape.streamer
            : _ConfettiShape.gem;
        final color = palette[(i + 4) % palette.length];

        particles.add(
          _CelebrationParticle(
            origin: origin,
            shape: shape,
            angle: angle,
            speed: speed,
            color: color,
            size: _sizeForShape(shape, i),
            spinSpeed: (i.isEven ? -1.0 : 1.0) * (1.2 + i * 0.2),
            wobbleFrequency: 2.2 + (i % 3) * 0.5,
            delay: 0.20 + (i % 4) * 0.02,
            gravity: 0.62 + (i % 2) * 0.1,
          ),
        );
      }
    }

    // --- Wave 3 (Perfect score only): Golden top shower cascade (delay 0.38 -> 0.48) ---
    if (isPerfect) {
      for (var i = 0; i < 14; i++) {
        final angle = -math.pi / 2 + (-0.55 + (i / 13) * 1.1);
        final speed = 0.28 + (i % 4) * 0.05;
        final shape = (i % 3 == 0)
            ? _ConfettiShape.coin
            : (i % 3 == 1 ? _ConfettiShape.star : _ConfettiShape.sparkle);
        final color = (i % 4 == 0) ? white : gold;

        particles.add(
          _CelebrationParticle(
            origin: _BurstOrigin.centerTop,
            shape: shape,
            angle: angle,
            speed: speed,
            color: color,
            size: _sizeForShape(shape, i) * 1.15,
            spinSpeed: (i.isEven ? 1.0 : -1.0) * (0.9 + (i % 3) * 0.3),
            wobbleFrequency: 2.5 + (i % 3) * 0.7,
            delay: 0.38 + (i % 5) * 0.02,
            gravity: 0.58 + (i % 2) * 0.08,
          ),
        );
      }
    }

    return particles;
  }

  _ConfettiShape _shapeForIndex(int index) {
    switch (index % 7) {
      case 0:
        return _ConfettiShape.rectangle;
      case 1:
        return _ConfettiShape.circle;
      case 2:
        return _ConfettiShape.streamer;
      case 3:
        return _ConfettiShape.star;
      case 4:
        return _ConfettiShape.sparkle;
      case 5:
        return _ConfettiShape.gem;
      case 6:
      default:
        return _ConfettiShape.coin;
    }
  }

  double _sizeForShape(_ConfettiShape shape, int index) {
    final base = (index % 3) * 1.2;
    switch (shape) {
      case _ConfettiShape.rectangle:
        return 6.5 + base;
      case _ConfettiShape.circle:
        return 5.0 + base;
      case _ConfettiShape.streamer:
        return 7.0 + base;
      case _ConfettiShape.star:
        return 6.8 + base;
      case _ConfettiShape.sparkle:
        return 6.2 + base;
      case _ConfettiShape.gem:
        return 6.0 + base;
      case _ConfettiShape.coin:
        return 7.5 + base;
      case _ConfettiShape.ember:
        return 4.0 + base;
    }
  }
}

/// Paints a subtle, atmospheric radial glow behind the result/reward area.
class _GlowPainter extends CustomPainter {
  final AppThemeColors colors;
  final double progress;
  final CelebrationType type;

  const _GlowPainter({
    required this.colors,
    required this.progress,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 0.82) return;

    final double opacity;
    if (progress < 0.22) {
      opacity = (progress / 0.22).clamp(0.0, 1.0);
    } else {
      opacity = (1.0 - (progress - 0.22) / 0.60).clamp(0.0, 1.0);
    }

    final center = Offset(size.width * 0.5, size.height * 0.40);
    final radius = size.shortestSide *
        (type == CelebrationType.perfect ? 0.62 : 0.48);

    final List<Color> gradientColors = switch (type) {
      CelebrationType.perfect => [
        AppColors.coinGold.withValues(alpha: 0.30 * opacity),
        AppColors.violet.withValues(alpha: 0.15 * opacity),
        Colors.transparent,
      ],
      CelebrationType.standard => [
        AppColors.primary.withValues(alpha: 0.22 * opacity),
        AppColors.secondary.withValues(alpha: 0.10 * opacity),
        Colors.transparent,
      ],
      CelebrationType.subdued => [
        colors.error.withValues(alpha: 0.14 * opacity),
        colors.error.withValues(alpha: 0.05 * opacity),
        Colors.transparent,
      ],
    };

    final paint = Paint()
      ..shader = RadialGradient(
        colors: gradientColors,
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.type != type ||
        oldDelegate.colors != colors;
  }
}

/// Paints high-energy confetti poppers, stars, sparkles, coins, gems, and floating embers.
class _CelebrationPainter extends CustomPainter {
  final AppThemeColors colors;
  final List<_CelebrationParticle> particles;
  final double progress;
  final CelebrationType type;

  // Cached Path singletons for reuse during drawing (avoids allocation in loop)
  static final Map<double, Path> _starPathCache = {};
  static final Map<double, Path> _sparklePathCache = {};
  static final Map<double, Path> _gemPathCache = {};

  const _CelebrationPainter({
    required this.colors,
    required this.particles,
    required this.progress,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // 1. Draw popper cannon burst graphics for active explosion waves
    if (type != CelebrationType.subdued) {
      _paintPopper(canvas, size, _BurstOrigin.bottomLeft);
      _paintPopper(canvas, size, _BurstOrigin.bottomRight);
      _paintPopper(canvas, size, _BurstOrigin.topLeft);
      _paintPopper(canvas, size, _BurstOrigin.topRight);
    }

    // 2. Render all active particles
    for (final p in particles) {
      final localProgress =
          ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0).toDouble();
      if (localProgress <= 0 || localProgress >= 1.0) continue;

      final origin = _resolveOrigin(p.origin, size);
      final isMirrored = p.origin == _BurstOrigin.bottomRight ||
          p.origin == _BurstOrigin.topRight;

      // Coordinate physics: explosive easeOut velocity + gravity drop + sway
      final velocity = Curves.easeOutCubic.transform(localProgress);
      final distance = size.shortestSide * p.speed;
      final horizontalDir = isMirrored ? -1.0 : 1.0;

      final sway = math.sin(localProgress * math.pi * p.wobbleFrequency) *
          (size.width * 0.028);

      final dx =
          math.cos(p.angle) * distance * velocity * horizontalDir + sway;
      final dy = math.sin(p.angle) * distance * velocity +
          (size.height * 0.42 * p.gravity * localProgress * localProgress);

      final center = origin + Offset(dx, dy);

      // Smooth fade-out in final 35% of particle lifespan
      final fade = localProgress < 0.65
          ? 1.0
          : (1.0 - (localProgress - 0.65) / 0.35).clamp(0.0, 1.0).toDouble();

      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.90 * fade)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(center.dx, center.dy);

      final spin = progress * math.pi * p.spinSpeed;
      canvas.rotate(spin);

      _drawParticleShape(canvas, p, paint, spin);

      canvas.restore();
    }
  }

  Offset _resolveOrigin(_BurstOrigin origin, Size size) {
    switch (origin) {
      case _BurstOrigin.bottomLeft:
        return Offset(size.width * 0.04, size.height * 0.82);
      case _BurstOrigin.bottomRight:
        return Offset(size.width * 0.96, size.height * 0.82);
      case _BurstOrigin.topLeft:
        return Offset(size.width * 0.05, size.height * 0.12);
      case _BurstOrigin.topRight:
        return Offset(size.width * 0.95, size.height * 0.12);
      case _BurstOrigin.centerTop:
        return Offset(size.width * 0.50, size.height * 0.04);
    }
  }

  void _drawParticleShape(
    Canvas canvas,
    _CelebrationParticle p,
    Paint paint,
    double spin,
  ) {
    final s = p.size;

    switch (p.shape) {
      case _ConfettiShape.rectangle:
        // 3D paper flutter simulation
        canvas.scale(math.cos(spin * 1.5).abs().clamp(0.18, 1.0), 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: s * 1.6,
              height: s * 0.95,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
        break;

      case _ConfettiShape.circle:
        canvas.drawCircle(Offset.zero, s * 0.5, paint);
        break;

      case _ConfettiShape.streamer:
        // Elongated twisting ribbon
        canvas.scale(math.cos(spin * 2.0).abs().clamp(0.2, 1.0), 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: s * 2.6,
              height: s * 0.65,
            ),
            const Radius.circular(1.0),
          ),
          paint,
        );
        break;

      case _ConfettiShape.star:
        final starPath = _getStarPath(s);
        canvas.drawPath(starPath, paint);
        break;

      case _ConfettiShape.sparkle:
        final sparklePath = _getSparklePath(s);
        canvas.drawPath(sparklePath, paint);
        break;

      case _ConfettiShape.gem:
        final gemPath = _getGemPath(s);
        canvas.drawPath(gemPath, paint);
        break;

      case _ConfettiShape.coin:
        // Gold coin with subtle inner highlight rim
        canvas.drawCircle(Offset.zero, s * 0.65, paint);
        final rimPaint = Paint()
          ..color = Colors.white.withValues(alpha: paint.color.a * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset.zero, s * 0.42, rimPaint);
        break;

      case _ConfettiShape.ember:
        // Soft glowing ember
        canvas.drawCircle(Offset.zero, s * 0.5, paint);
        break;
    }
  }

  Path _getStarPath(double radius) {
    final key = (radius * 10).round() / 10;
    return _starPathCache.putIfAbsent(key, () {
      final path = Path();
      final innerRadius = radius * 0.42;
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? radius : innerRadius;
        final angle = (i * 36 - 90) * math.pi / 180;
        final x = math.cos(angle) * r;
        final y = math.sin(angle) * r;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      return path;
    });
  }

  Path _getSparklePath(double radius) {
    final key = (radius * 10).round() / 10;
    return _sparklePathCache.putIfAbsent(key, () {
      final path = Path();
      final inner = radius * 0.22;
      path.moveTo(0, -radius);
      path.lineTo(inner, -inner);
      path.lineTo(radius, 0);
      path.lineTo(inner, inner);
      path.lineTo(0, radius);
      path.lineTo(-inner, inner);
      path.lineTo(-radius, 0);
      path.lineTo(-inner, -inner);
      path.close();
      return path;
    });
  }

  Path _getGemPath(double radius) {
    final key = (radius * 10).round() / 10;
    return _gemPathCache.putIfAbsent(key, () {
      final path = Path();
      path.moveTo(0, -radius);
      path.lineTo(radius * 0.85, -radius * 0.35);
      path.lineTo(radius * 0.55, radius);
      path.lineTo(-radius * 0.55, radius);
      path.lineTo(-radius * 0.85, -radius * 0.35);
      path.close();
      return path;
    });
  }

  void _paintPopper(Canvas canvas, Size size, _BurstOrigin origin) {
    // Cannon blast rays flash during first wave (0 -> 0.28) and second wave (0.22 -> 0.45)
    final double waveProgress;
    if (progress < 0.28) {
      waveProgress = (progress / 0.28).clamp(0.0, 1.0);
    } else if (progress < 0.45) {
      waveProgress = ((progress - 0.22) / 0.23).clamp(0.0, 1.0);
    } else {
      return;
    }

    final fade = (1.0 - waveProgress).clamp(0.0, 1.0);
    if (fade <= 0) return;

    final pos = _resolveOrigin(origin, size);
    final isTop =
        origin == _BurstOrigin.topLeft || origin == _BurstOrigin.topRight;
    final isRight =
        origin == _BurstOrigin.bottomRight || origin == _BurstOrigin.topRight;

    final baseRotation = isTop
        ? (isRight ? 2.4 : 0.75)
        : (isRight ? -2.4 : -0.75);

    final linePaint = Paint()
      ..color = AppColors.coinGold.withValues(alpha: 0.45 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(baseRotation);

    for (var ray = 0; ray < 4; ray++) {
      final angle = -0.38 + ray * 0.25;
      final length = 22.0 + ray * 5;
      final rayProgress = Curves.easeOutCubic.transform(waveProgress);
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * length, math.sin(angle) * length) *
            rayProgress,
        linePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.particles != particles ||
        oldDelegate.progress != progress ||
        oldDelegate.type != type;
  }
}

enum _BurstOrigin {
  bottomLeft,
  bottomRight,
  topLeft,
  topRight,
  centerTop,
}

enum _ConfettiShape {
  rectangle,
  circle,
  streamer,
  star,
  sparkle,
  gem,
  coin,
  ember,
}

class _CelebrationParticle {
  final _BurstOrigin origin;
  final _ConfettiShape shape;
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spinSpeed;
  final double wobbleFrequency;
  final double delay;
  final double gravity;

  const _CelebrationParticle({
    required this.origin,
    required this.shape,
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.spinSpeed,
    required this.wobbleFrequency,
    required this.delay,
    required this.gravity,
  });
}
