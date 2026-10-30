import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_elevation.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/app_typography.dart';

/// A card-sized choice with wrapping text and native button accessibility.
class AppChoiceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback? onPressed;

  const AppChoiceCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final edge = selected
        ? AppElevation.edgeColor(accentColor)
        : accentColor.withValues(alpha: 0.4);
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.only(
          top: selected ? 2 : 0,
          bottom: selected
              ? AppDimensions.cardDepth - 2
              : AppDimensions.cardDepth,
        ),
        decoration: BoxDecoration(
          borderRadius: AppDimensions.radiusCard,
          boxShadow: [
            BoxShadow(
              color: Color.alphaBlend(edge, colors.surface),
              offset: Offset(0, selected ? 2 : AppDimensions.cardDepth),
            ),
            if (selected) ...AppElevation.glow(accentColor, strength: 0.6),
          ],
        ),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: AppSpacing.paddingMd,
            minimumSize: const Size.fromHeight(100),
            foregroundColor: colors.textPrimary,
            disabledForegroundColor: colors.textSecondary,
            backgroundColor: Color.alphaBlend(
              accentColor.withValues(alpha: selected ? 0.22 : 0.06),
              colors.surface,
            ),
            side: BorderSide(
              color: accentColor.withValues(alpha: selected ? 1 : 0.5),
              width: selected ? 3 : AppDimensions.borderWidth,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppDimensions.radiusCard,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.appTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Icon(icon, color: accentColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
