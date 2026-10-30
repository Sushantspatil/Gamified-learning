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
    final borderColor = _borderColor(colors, isLight: isLight);
    final background = _backgroundColor(colors, isLight: isLight);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: isLight ? 0.0 : 0.035),
              background,
            ),
            background,
          ],
        ),
        borderRadius: resolvedRadius,
        border: Border.all(
          color: borderColor,
          width: AppDimensions.borderWidth,
        ),
        boxShadow: [
          // Solid lower edge that makes the card read as a raised tile.
          if (elevationLevel > 0)
            BoxShadow(
              color: Color.alphaBlend(borderColor, background),
              offset: const Offset(0, AppDimensions.cardDepth),
            ),
          ...AppElevation.shadows(colors, elevationLevel),
        ],
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
        tint.withValues(alpha: isLight ? 0.10 : 0.20),
        colors.surface,
      ),
    };
  }

  Color _borderColor(AppThemeColors colors, {required bool isLight}) {
    return switch (variant) {
      AppCardVariant.surface => colors.border,
      AppCardVariant.outlined => colors.borderStrong,
      AppCardVariant.tinted => (tintColor ?? colors.primary).withValues(
        alpha: isLight ? 0.45 : 0.55,
      ),
    };
  }
}
