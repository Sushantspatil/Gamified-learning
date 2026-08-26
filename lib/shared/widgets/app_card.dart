import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_elevation.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_colors.dart';

enum AppCardVariant { surface, outlined, tinted }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final int elevationLevel;
  final Color? tintColor;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.surface,
    this.padding = AppSpacing.paddingMd,
    this.borderRadius,
    this.elevationLevel = 1,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final resolvedRadius = borderRadius ?? AppDimensions.radiusCard;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor(colors),
        gradient: _backgroundGradient(colors),
        borderRadius: resolvedRadius,
        border: Border.all(color: _borderColor(colors)),
        boxShadow: AppElevation.shadows(colors, elevationLevel),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Color _backgroundColor(AppThemeColors colors) {
    return switch (variant) {
      AppCardVariant.surface || AppCardVariant.outlined => Colors.transparent,
      AppCardVariant.tinted => (tintColor ?? colors.primary).withValues(
        alpha: 0.08,
      ),
    };
  }

  Gradient? _backgroundGradient(AppThemeColors colors) {
    return switch (variant) {
      AppCardVariant.surface => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.cardBackground,
          colors.surfaceElevated.withValues(alpha: 0.86),
        ],
      ),
      AppCardVariant.outlined => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.surface, colors.cardBackground],
      ),
      AppCardVariant.tinted => null,
    };
  }

  Color _borderColor(AppThemeColors colors) {
    return switch (variant) {
      AppCardVariant.surface => colors.border,
      AppCardVariant.outlined => colors.borderStrong,
      AppCardVariant.tinted => (tintColor ?? colors.primary).withValues(
        alpha: 0.18,
      ),
    };
  }
}
