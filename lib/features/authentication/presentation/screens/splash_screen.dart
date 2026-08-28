import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';

/// Purely presentational. Navigation away from splash is driven by
/// RouteGuards.redirect once startup providers resolve.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final reduceMotion = AppMotion.reduceMotion(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.background,
              colors.backgroundSecondary,
              colors.surfaceElevated,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SplashSparkPainter(colors)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 238,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final t = reduceMotion ? 0.0 : _controller.value;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    left: 6,
                                    top: 58 + _float(t, 0, 8),
                                    child: _SplashCharacter(
                                      accent: colors.secondary,
                                      icon: Icons.auto_stories_rounded,
                                      label: 'Learn',
                                      scale: 0.9,
                                      glowOpacity: 0.20,
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 26 + _float(t, 0.35, 10),
                                    child: _SplashCharacter(
                                      accent: colors.violet,
                                      icon: Icons.psychology_rounded,
                                      label: 'Think',
                                      scale: 0.88,
                                      glowOpacity: 0.18,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4 + _float(t, 0.7, 9),
                                    child: _SplashCharacter(
                                      accent: colors.primary,
                                      icon: Icons.waving_hand_rounded,
                                      label: 'Welcome',
                                      scale: 1.08,
                                      glowOpacity: 0.26,
                                      isWelcoming: true,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: AppMotion.duration(context, AppMotion.slow),
                          curve: AppMotion.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  reduceMotion ? 0 : 14 * (1 - value),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Text(
                                AppConstants.appName,
                                textAlign: TextAlign.center,
                                style: context.appTextStyles.displayLarge
                                    .copyWith(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      color: colors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Your next learning quest is loading',
                                textAlign: TextAlign.center,
                                style: context.appTextStyles.bodyMedium
                                    .copyWith(color: colors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              SizedBox(
                                width: 190,
                                child: ClipRRect(
                                  borderRadius: AppDimensions.radiusCircular,
                                  child: LinearProgressIndicator(
                                    minHeight: 8,
                                    color: colors.primary,
                                    backgroundColor: colors.primary.withValues(
                                      alpha: 0.16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _float(double t, double phase, double distance) {
    return math.sin((t + phase) * math.pi * 2) * distance;
  }
}

class _SplashCharacter extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String label;
  final double scale;
  final double glowOpacity;
  final bool isWelcoming;

  const _SplashCharacter({
    required this.accent,
    required this.icon,
    required this.label,
    required this.scale,
    required this.glowOpacity,
    this.isWelcoming = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: glowOpacity),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SizedBox(
          width: 132,
          height: 156,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 38,
                child: Container(
                  width: 104,
                  height: 106,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.cardBackground,
                        accent.withValues(alpha: 0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: accent.withValues(alpha: 0.34)),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.38),
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, color: accent, size: isWelcoming ? 36 : 32),
                ),
              ),
              Positioned(
                top: 72,
                left: 48,
                child: _CharacterEye(color: colors.textPrimary),
              ),
              Positioned(
                top: 72,
                right: 48,
                child: _CharacterEye(color: colors.textPrimary),
              ),
              Positioned(
                top: 91,
                child: Container(
                  width: 28,
                  height: 10,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.textPrimary, width: 2),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              if (isWelcoming)
                Positioned(
                  right: 0,
                  top: 64,
                  child: Transform.rotate(
                    angle: -0.32,
                    child: Icon(
                      Icons.back_hand_rounded,
                      color: accent,
                      size: 28,
                    ),
                  ),
                ),
              Positioned(
                bottom: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: AppDimensions.radiusCircular,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      label,
                      style: AppTypography.badge.copyWith(
                        color: colors.primaryForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterEye extends StatelessWidget {
  final Color color;

  const _CharacterEye({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SplashSparkPainter extends CustomPainter {
  final AppThemeColors colors;

  const _SplashSparkPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.primary.withValues(alpha: 0.10)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final secondaryPaint = Paint()
      ..color = colors.secondary.withValues(alpha: 0.09)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final centers = <Offset>[
      Offset(size.width * 0.18, size.height * 0.16),
      Offset(size.width * 0.82, size.height * 0.24),
      Offset(size.width * 0.12, size.height * 0.72),
      Offset(size.width * 0.78, size.height * 0.68),
      Offset(size.width * 0.48, size.height * 0.08),
    ];

    for (var index = 0; index < centers.length; index++) {
      final center = centers[index];
      final radius = index.isEven ? 10.0 : 7.0;
      final selectedPaint = index.isEven ? paint : secondaryPaint;
      canvas
        ..drawLine(
          Offset(center.dx - radius, center.dy),
          Offset(center.dx + radius, center.dy),
          selectedPaint,
        )
        ..drawLine(
          Offset(center.dx, center.dy - radius),
          Offset(center.dx, center.dy + radius),
          selectedPaint,
        );
    }
  }

  @override
  bool shouldRepaint(_SplashSparkPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
