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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final resolvedRadius = borderRadius ?? AppDimensions.radiusCard;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        gradient: _backgroundGradient(colors, isLight: isLight),
        borderRadius: resolvedRadius,
        border: Border.all(color: _borderColor(colors, isLight: isLight)),
        boxShadow: AppElevation.shadows(colors, elevationLevel),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Gradient _backgroundGradient(AppThemeColors colors, {required bool isLight}) {
    final tint = tintColor ?? colors.primary;

    return switch (variant) {
      AppCardVariant.surface => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.cardBackground,
          isLight ? colors.surface : colors.surfaceElevated,
        ],
      ),
      AppCardVariant.outlined => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.surface, colors.cardBackground],
      ),
      AppCardVariant.tinted => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            tint.withValues(alpha: isLight ? 0.12 : 0.18),
            colors.surface,
          ),
          Color.alphaBlend(
            tint.withValues(alpha: isLight ? 0.04 : 0.10),
            colors.surfaceElevated,
          ),
        ],
      ),
    };
  }

  Color _borderColor(AppThemeColors colors, {required bool isLight}) {
    return switch (variant) {
      AppCardVariant.surface => colors.border,
      AppCardVariant.outlined => colors.borderStrong,
      AppCardVariant.tinted => (tintColor ?? colors.primary).withValues(
        alpha: isLight ? 0.30 : 0.22,
      ),
    };
  }
}
