import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_elevation.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';

class ProfileStatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const ProfileStatChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: AppDimensions.radiusCircular,
        border: Border.all(
          color: iconColor.withValues(alpha: 0.6),
          width: AppDimensions.borderWidth,
        ),
        boxShadow: AppElevation.raised(
          Color.alphaBlend(
            AppElevation.edgeColor(iconColor).withValues(alpha: 0.7),
            colors.surface,
          ),
          depth: 3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.button.copyWith(
              color: colors.textPrimary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
