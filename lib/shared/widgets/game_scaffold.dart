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

    return Scaffold(
      appBar: appBar,
      backgroundColor: colors.background,
      bottomNavigationBar: bottomNavigationBar,
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.background,
              colors.backgroundSecondary,
              colors.background,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GameSparkPainter(colors)),
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

  const _GameSparkPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final secondaryPaint = Paint()
      ..color = colors.secondary.withValues(alpha: 0.07)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final sparks = <Offset>[
      Offset(size.width * 0.12, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.18),
      Offset(size.width * 0.18, size.height * 0.42),
      Offset(size.width * 0.74, size.height * 0.56),
      Offset(size.width * 0.34, size.height * 0.78),
      Offset(size.width * 0.9, size.height * 0.84),
    ];

    for (var index = 0; index < sparks.length; index++) {
      final center = sparks[index];
      final radius = index.isEven ? 8.0 : 6.0;
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
  bool shouldRepaint(_GameSparkPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
