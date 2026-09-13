import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';

enum McqCharacterState { idle, thinking, acknowledge, powerUp, transition }

class McqCharacterWidget extends StatelessWidget {
  final McqCharacterState state;
  final String? message;

  const McqCharacterWidget({super.key, required this.state, this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final isCompact = MediaQuery.sizeOf(context).height < 700;
    final avatarSize = isCompact ? 82.0 : 128.0;
    final effectiveMessage = message ?? _messageForState(state);

    return Semantics(
      container: true,
      label: 'MCQ companion',
      child: SizedBox(
        key: const Key('mcq_character_section'),
        height: isCompact ? 96 : 168,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              bottom: state == McqCharacterState.transition
                  ? 4
                  : isCompact
                  ? 8
                  : 18,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: state == McqCharacterState.transition ? 0.72 : 1,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  scale: switch (state) {
                    McqCharacterState.powerUp => 1.06,
                    McqCharacterState.acknowledge => 1.03,
                    McqCharacterState.transition => 0.96,
                    _ => 1,
                  },
                  child: SizedBox(
                    width: avatarSize,
                    height: avatarSize,
                    child: CustomPaint(
                      painter: _McqCompanionPainter(
                        colors: colors,
                        state: state,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              left: avatarSize * 0.58,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _SpeechBubble(
                  key: ValueKey(effectiveMessage),
                  text: effectiveMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageForState(McqCharacterState state) {
    return switch (state) {
      McqCharacterState.idle => 'Think carefully.',
      McqCharacterState.thinking => 'Need a clue?',
      McqCharacterState.acknowledge => 'Nice choice.',
      McqCharacterState.powerUp => 'Scanning options.',
      McqCharacterState.transition => 'Skipping ahead.',
    };
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;

  const _SpeechBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Align(
      alignment: Alignment.topCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
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
      ),
    );
  }
}

class _McqCompanionPainter extends CustomPainter {
  final AppThemeColors colors;
  final McqCharacterState state;

  const _McqCompanionPainter({required this.colors, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final bodyColor = switch (state) {
      McqCharacterState.thinking => colors.secondary,
      McqCharacterState.powerUp => colors.violet,
      McqCharacterState.transition => colors.primaryDark,
      _ => colors.primary,
    };
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              bodyColor.withValues(alpha: 0.28),
              colors.secondary.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.54),
          );
    canvas.drawCircle(center, size.width * 0.5, glowPaint);

    final platformPaint = Paint()
      ..color = colors.primaryDark.withValues(alpha: 0.72);
    final platform = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.82,
        size.width * 0.56,
        10,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(platform, platformPaint);

    final bodyPaint = Paint()..color = bodyColor;
    final facePaint = Paint()..color = colors.surface;
    final eyePaint = Paint()..color = colors.textPrimary;
    final accentPaint = Paint()..color = AppColors.coinGold;
    final armPaint = Paint()
      ..color = bodyColor
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, size.width * 0.27, bodyPaint);
    canvas.drawCircle(
      Offset(center.dx, center.dy - 5),
      size.width * 0.22,
      facePaint,
    );

    final leftArmEnd = switch (state) {
      McqCharacterState.thinking => Offset(center.dx - 34, center.dy - 16),
      McqCharacterState.powerUp => Offset(center.dx - 42, center.dy - 4),
      McqCharacterState.transition => Offset(center.dx - 38, center.dy + 18),
      _ => Offset(center.dx - 34, center.dy + 10),
    };
    final rightArmEnd = switch (state) {
      McqCharacterState.acknowledge => Offset(center.dx + 42, center.dy - 18),
      McqCharacterState.powerUp => Offset(center.dx + 42, center.dy - 4),
      McqCharacterState.transition => Offset(center.dx + 46, center.dy + 12),
      _ => Offset(center.dx + 34, center.dy + 10),
    };
    canvas.drawLine(
      Offset(center.dx - 22, center.dy + 6),
      leftArmEnd,
      armPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 22, center.dy + 6),
      rightArmEnd,
      armPaint,
    );

    canvas.drawCircle(Offset(center.dx - 10, center.dy - 11), 4.2, eyePaint);
    canvas.drawCircle(Offset(center.dx + 10, center.dy - 11), 4.2, eyePaint);

    final smilePaint = Paint()
      ..color = eyePaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final smileRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 2),
      width: state == McqCharacterState.thinking ? 16 : 24,
      height: state == McqCharacterState.thinking ? 7 : 14,
    );
    canvas.drawArc(smileRect, 0.15, 2.8, false, smilePaint);

    final capPath = Path()
      ..moveTo(center.dx - 32, center.dy - 35)
      ..lineTo(center.dx, center.dy - 55)
      ..lineTo(center.dx + 32, center.dy - 35)
      ..lineTo(center.dx, center.dy - 20)
      ..close();
    canvas.drawPath(capPath, accentPaint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 29),
        width: 45,
        height: 8,
      ),
      Paint()..color = colors.primaryDark,
    );

    if (state == McqCharacterState.powerUp) {
      final scanPaint = Paint()
        ..color = colors.secondary.withValues(alpha: 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, size.width * 0.38, scanPaint);
      canvas.drawCircle(center, size.width * 0.45, scanPaint);
    }
  }

  @override
  bool shouldRepaint(_McqCompanionPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.state != state;
  }
}
