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
        color: _backgroundColor(colors, isLight: isLight),
        borderRadius: resolvedRadius,
        border: Border.all(color: _borderColor(colors, isLight: isLight)),
        boxShadow: AppElevation.shadows(colors, elevationLevel),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Color _backgroundColor(AppThemeColors colors, {required bool isLight}) {
    final tint = tintColor ?? colors.primary;

    return switch (variant) {
      AppCardVariant.surface => colors.cardBackground,
      AppCardVariant.outlined => colors.surface,
      AppCardVariant.tinted => Color.alphaBlend(
        tint.withValues(alpha: isLight ? 0.08 : 0.16),
        colors.surface,
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
