import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';

enum McqCharacterState { idle, thinking, acknowledge, powerUp, transition }

class McqCharacterWidget extends StatefulWidget {
  final McqCharacterState state;
  final String? message;

  const McqCharacterWidget({super.key, required this.state, this.message});

  @override
  State<McqCharacterWidget> createState() => _McqCharacterWidgetState();
}

class _McqCharacterWidgetState extends State<McqCharacterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context) && _idleController.isAnimating) {
      _idleController.stop();
    } else if (!AppMotion.reduceMotion(context) &&
        !_idleController.isAnimating) {
      _idleController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).height < 700;
    final characterSize = isCompact ? 112.0 : 150.0;
    final sectionHeight = isCompact ? 132.0 : 178.0;
    final effectiveMessage = widget.message ?? _messageForState(widget.state);
    final reduceMotion = AppMotion.reduceMotion(context);

    return Semantics(
      container: true,
      label: 'MCQ companion',
      child: SizedBox(
        key: const Key('mcq_character_section'),
        height: sectionHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('mcq-companion-zone-${widget.state}'),
                tween: Tween<double>(begin: 0, end: 1),
                duration: AppMotion.duration(context, AppMotion.slow),
                curve: AppMotion.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 8),
                      child: child,
                    ),
                  );
                },
                child: CustomPaint(
                  painter: _CompanionStagePainter(
                    colors: context.themeColors,
                    state: widget.state,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.fast),
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeIn,
                child: _SpeechBubble(
                  key: ValueKey(effectiveMessage),
                  text: effectiveMessage,
                  state: widget.state,
                ),
              ),
            ),
            Positioned(
              bottom: isCompact ? 2 : 4,
              child: AnimatedBuilder(
                animation: _idleController,
                builder: (context, child) {
                  final t = reduceMotion ? 0.0 : _idleController.value;
                  final bob = math.sin(t * math.pi) * 4;
                  final breathe = 1 + math.sin(t * math.pi) * 0.008;

                  return AnimatedOpacity(
                    duration: AppMotion.duration(context, AppMotion.normal),
                    opacity: widget.state == McqCharacterState.transition
                        ? 0.68
                        : 1,
                    child: AnimatedScale(
                      duration: AppMotion.duration(context, AppMotion.normal),
                      curve: AppMotion.easeOut,
                      scale: _stateScale(widget.state) * breathe,
                      child: AnimatedSlide(
                        duration: AppMotion.duration(context, AppMotion.normal),
                        curve: AppMotion.easeOut,
                        offset: widget.state == McqCharacterState.transition
                            ? const Offset(0.18, 0.06)
                            : Offset(0, -bob / characterSize),
                        child: SizedBox(
                          width: characterSize,
                          height: characterSize,
                          child: CustomPaint(
                            key: const Key('mcq_scholar_companion_art'),
                            painter: _ScholarCompanionPainter(
                              colors: context.themeColors,
                              state: widget.state,
                              idleValue: t,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _stateScale(McqCharacterState state) {
    return switch (state) {
      McqCharacterState.acknowledge => 1.025,
      McqCharacterState.powerUp => 1.045,
      McqCharacterState.transition => 0.96,
      _ => 1,
    };
  }

  String _messageForState(McqCharacterState state) {
    return switch (state) {
      McqCharacterState.idle => 'Think carefully.',
      McqCharacterState.thinking => 'Need help?',
      McqCharacterState.acknowledge => 'Nice choice.',
      McqCharacterState.powerUp => "Let's narrow it down.",
      McqCharacterState.transition => 'Next one!',
    };
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  final McqCharacterState state;

  const _SpeechBubble({super.key, required this.text, required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final accent = switch (state) {
      McqCharacterState.powerUp => colors.secondary,
      McqCharacterState.thinking => colors.warning,
      McqCharacterState.transition => colors.violet,
      _ => colors.primary,
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.surfaceElevated.withValues(alpha: 0.94),
              colors.background,
            ),
            borderRadius: AppDimensions.radiusMd,
            border: Border.all(color: accent.withValues(alpha: 0.36)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.ms,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.labelLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanionStagePainter extends CustomPainter {
  final AppThemeColors colors;
  final McqCharacterState state;

  const _CompanionStagePainter({required this.colors, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.62);
    final accent = switch (state) {
      McqCharacterState.powerUp => colors.secondary,
      McqCharacterState.thinking => colors.warning,
      McqCharacterState.transition => colors.violet,
      _ => colors.primary,
    };

    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.18),
              colors.violet.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.34),
          );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.74,
        height: size.height * 0.78,
      ),
      haloPaint,
    );

    final basePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.30),
              colors.primaryDark.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(size.width * 0.5, size.height * 0.92),
              width: size.width * 0.48,
              height: size.height * 0.22,
            ),
          );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.92),
        width: size.width * 0.52,
        height: size.height * 0.17,
      ),
      basePaint,
    );

    final particlePaint = Paint()..color = accent.withValues(alpha: 0.55);
    for (final particle in const [
      Offset(0.28, 0.35),
      Offset(0.70, 0.36),
      Offset(0.22, 0.62),
      Offset(0.78, 0.58),
    ]) {
      canvas.drawCircle(
        Offset(size.width * particle.dx, size.height * particle.dy),
        size.shortestSide * 0.011,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CompanionStagePainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.state != state;
  }
}

class _ScholarCompanionPainter extends CustomPainter {
  final AppThemeColors colors;
  final McqCharacterState state;
  final double idleValue;

  const _ScholarCompanionPainter({
    required this.colors,
    required this.state,
    required this.idleValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 150;
    final sy = size.height / 150;
    canvas.save();
    canvas.scale(sx, sy);

    final accent = switch (state) {
      McqCharacterState.powerUp => colors.secondary,
      McqCharacterState.thinking => colors.warning,
      McqCharacterState.transition => colors.violet,
      _ => colors.primary,
    };
    final jacket = Paint()..color = colors.primaryDark;
    final jacketLight = Paint()..color = colors.primary;
    final face = Paint()..color = const Color(0xFFFFD6B8);
    final hair = Paint()..color = const Color(0xFF282036);
    final cyan = Paint()..color = colors.secondary;
    final gold = Paint()..color = AppColors.coinGold;
    final line = Paint()
      ..color = colors.textPrimary.withValues(alpha: 0.82)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.28),
          colors.primary.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(16, 18, 118, 118));
    canvas.drawCircle(const Offset(76, 78), 60, glow);

    final shadow = Paint()..color = colors.primaryDark.withValues(alpha: 0.44);
    canvas.drawOval(const Rect.fromLTWH(43, 128, 66, 12), shadow);

    final capePath = Path()
      ..moveTo(48, 67)
      ..quadraticBezierTo(28, 91, 40, 128)
      ..quadraticBezierTo(75, 140, 110, 128)
      ..quadraticBezierTo(123, 91, 102, 67)
      ..close();
    canvas.drawPath(
      capePath,
      Paint()..color = colors.violet.withValues(alpha: 0.72),
    );

    final torsoPath = Path()
      ..moveTo(49, 74)
      ..quadraticBezierTo(75, 63, 101, 74)
      ..lineTo(113, 128)
      ..quadraticBezierTo(75, 139, 37, 128)
      ..close();
    canvas.drawPath(torsoPath, jacket);

    final shirtPath = Path()
      ..moveTo(64, 73)
      ..lineTo(75, 101)
      ..lineTo(87, 73)
      ..quadraticBezierTo(75, 68, 64, 73)
      ..close();
    canvas.drawPath(shirtPath, Paint()..color = colors.surface);

    final leftPanel = Path()
      ..moveTo(51, 75)
      ..quadraticBezierTo(59, 88, 70, 105)
      ..lineTo(56, 128)
      ..lineTo(37, 128)
      ..close();
    canvas.drawPath(leftPanel, jacketLight);

    final rightPanel = Path()
      ..moveTo(99, 75)
      ..quadraticBezierTo(91, 88, 80, 105)
      ..lineTo(94, 128)
      ..lineTo(113, 128)
      ..close();
    canvas.drawPath(
      rightPanel,
      Paint()..color = colors.primary.withValues(alpha: 0.84),
    );

    final neck = RRect.fromRectAndRadius(
      const Rect.fromLTWH(66, 57, 18, 23),
      const Radius.circular(8),
    );
    canvas.drawRRect(neck, face);

    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(50, 25, 50, 45),
      const Radius.circular(20),
    );
    canvas.drawRRect(head, face);

    final hairPath = Path()
      ..moveTo(51, 43)
      ..quadraticBezierTo(55, 19, 82, 21)
      ..quadraticBezierTo(103, 24, 101, 49)
      ..quadraticBezierTo(89, 38, 74, 39)
      ..quadraticBezierTo(63, 39, 51, 43)
      ..close();
    canvas.drawPath(hairPath, hair);

    final visorRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(58, 44, 35, 10),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      visorRect,
      Paint()..color = colors.primaryDark.withValues(alpha: 0.88),
    );
    canvas.drawRRect(
      visorRect.deflate(2),
      Paint()..color = colors.secondary.withValues(alpha: 0.62),
    );

    canvas.drawCircle(
      const Offset(64, 49),
      2.1,
      Paint()..color = colors.textPrimary,
    );
    canvas.drawCircle(
      const Offset(86, 49),
      2.1,
      Paint()..color = colors.textPrimary,
    );

    final mouthY = state == McqCharacterState.thinking ? 59.0 : 58.0;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(75, mouthY), width: 18, height: 9),
      0.10,
      state == McqCharacterState.thinking ? 2.3 : 2.85,
      false,
      line..strokeWidth = 2,
    );

    final capTop = Path()
      ..moveTo(44, 27)
      ..lineTo(75, 10)
      ..lineTo(106, 27)
      ..lineTo(75, 43)
      ..close();
    canvas.drawPath(capTop, gold);
    canvas.drawPath(
      Path()
        ..moveTo(57, 33)
        ..quadraticBezierTo(75, 42, 94, 33)
        ..lineTo(90, 46)
        ..quadraticBezierTo(75, 52, 60, 46)
        ..close(),
      Paint()..color = colors.primaryDark,
    );
    canvas.drawLine(
      const Offset(102, 29),
      const Offset(113, 48),
      line..strokeWidth = 2,
    );
    canvas.drawCircle(const Offset(114, 51), 4, gold);

    final tabletTilt = state == McqCharacterState.powerUp ? -0.08 : 0.04;
    canvas.save();
    canvas.translate(90, 84);
    canvas.rotate(tabletTilt);
    final tablet = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 38, 45),
      const Radius.circular(8),
    );
    canvas.drawRRect(tablet, Paint()..color = colors.surfaceElevated);
    canvas.drawRRect(
      tablet.deflate(4),
      Paint()..color = colors.backgroundSecondary.withValues(alpha: 0.92),
    );
    canvas.drawLine(
      const Offset(9, 13),
      const Offset(29, 13),
      line..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(9, 23),
      const Offset(24, 23),
      line..strokeWidth = 2,
    );
    canvas.drawCircle(const Offset(28, 33), 4, cyan);
    if (state == McqCharacterState.powerUp) {
      canvas.drawRRect(
        tablet.inflate(4),
        Paint()
          ..color = Colors.transparent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..shader = LinearGradient(
            colors: [colors.secondary, colors.violet],
          ).createShader(const Rect.fromLTWH(-4, -4, 46, 53)),
      );
    }
    canvas.restore();

    final leftArmEnd = switch (state) {
      McqCharacterState.thinking => const Offset(57, 58),
      McqCharacterState.acknowledge => const Offset(31, 71),
      McqCharacterState.transition => const Offset(31, 93),
      _ => const Offset(42, 98),
    };
    final rightArmEnd = switch (state) {
      McqCharacterState.powerUp => const Offset(93, 92),
      McqCharacterState.transition => const Offset(124, 83),
      _ => const Offset(98, 95),
    };
    final armPaint = Paint()
      ..color = colors.primary
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(55, 82), leftArmEnd, armPaint);
    canvas.drawLine(const Offset(96, 82), rightArmEnd, armPaint);
    canvas.drawCircle(leftArmEnd, 5.5, face);
    canvas.drawCircle(rightArmEnd, 5.5, face);

    if (state == McqCharacterState.powerUp) {
      final scan = Paint()
        ..color = colors.secondary.withValues(alpha: 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      final pulse = math.sin(idleValue * math.pi) * 4;
      canvas.drawCircle(const Offset(109, 106), 29 + pulse, scan);
      canvas.drawCircle(const Offset(109, 106), 39 + pulse, scan);
    }

    if (state == McqCharacterState.acknowledge) {
      canvas.drawPath(
        Path()
          ..moveTo(27, 64)
          ..lineTo(34, 72)
          ..lineTo(47, 57),
        Paint()
          ..color = colors.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScholarCompanionPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.state != state ||
        oldDelegate.idleValue != idleValue;
  }
}
