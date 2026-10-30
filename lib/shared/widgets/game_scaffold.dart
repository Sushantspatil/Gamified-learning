import 'package:flutter/material.dart';

import '../../app/theme/app_theme_colors.dart';

class GameScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  const GameScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: appBar,
      backgroundColor: colors.background,
      bottomNavigationBar: bottomNavigationBar,
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.backgroundSecondary,
              colors.background,
              colors.background,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _GameSparkPainter(colors, isLight)),
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}

class _GameSparkPainter extends CustomPainter {
  final AppThemeColors colors;
  final bool isLight;

  const _GameSparkPainter(this.colors, this.isLight);

  // Fixed star field (x, y as fractions of the screen, radius).
  static const _stars = <(double, double, double)>[
    (0.08, 0.06, 1.6),
    (0.27, 0.13, 1.0),
    (0.46, 0.05, 1.3),
    (0.71, 0.10, 1.8),
    (0.93, 0.04, 1.0),
    (0.15, 0.24, 1.2),
    (0.62, 0.21, 1.0),
    (0.88, 0.29, 1.4),
    (0.04, 0.39, 1.0),
    (0.36, 0.33, 1.6),
    (0.78, 0.43, 1.0),
    (0.22, 0.52, 1.3),
    (0.55, 0.48, 1.0),
    (0.95, 0.56, 1.6),
    (0.10, 0.66, 1.0),
    (0.42, 0.63, 1.4),
    (0.69, 0.70, 1.0),
    (0.86, 0.77, 1.2),
    (0.30, 0.81, 1.0),
    (0.05, 0.88, 1.5),
    (0.58, 0.90, 1.2),
    (0.80, 0.95, 1.0),
    (0.38, 0.97, 1.3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset center, double radius, Color color, double alpha) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final shortest = size.shortestSide;
    final glowAlpha = isLight ? 0.14 : 0.28;
    glow(
      Offset(size.width * 0.05, size.height * 0.02),
      shortest * 0.9,
      colors.primary,
      glowAlpha,
    );
    glow(
      Offset(size.width * 1.0, size.height * 0.45),
      shortest * 0.75,
      colors.violet,
      glowAlpha * 0.7,
    );
    glow(
      Offset(size.width * 0.1, size.height * 1.0),
      shortest * 0.8,
      colors.secondary,
      glowAlpha * 0.55,
    );

    final starPaint = Paint()
      ..color = (isLight ? colors.primary : Colors.white).withValues(
        alpha: isLight ? 0.16 : 0.5,
      );
    for (final (x, y, r) in _stars) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, starPaint);
    }

    // A few twinkling "+" sparkles.
    final sparkPaint = Paint()
      ..color = colors.secondary.withValues(alpha: isLight ? 0.22 : 0.4)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final (x, y, r) in const [
      (0.82, 0.16, 6.0),
      (0.16, 0.45, 5.0),
      (0.74, 0.62, 5.0),
      (0.34, 0.86, 6.0),
    ]) {
      final c = Offset(size.width * x, size.height * y);
      canvas
        ..drawLine(c.translate(-r, 0), c.translate(r, 0), sparkPaint)
        ..drawLine(c.translate(0, -r), c.translate(0, r), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_GameSparkPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.isLight != isLight;
}
