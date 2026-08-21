import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_theme_colors.dart';

class AppSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final radius = borderRadius ?? AppDimensions.radiusSm;

    if (AppMotion.reduceMotion(context)) {
      return _SkeletonBox(
        width: width,
        height: height,
        borderRadius: radius,
        color: colors.surfaceElevated,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: _SkeletonBox(
        width: width,
        height: height,
        borderRadius: radius,
        color: colors.surfaceElevated,
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final Color color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      child: SizedBox(width: width, height: height),
    );
  }
}
