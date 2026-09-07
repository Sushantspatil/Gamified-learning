import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
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
    return Semantics(
      selected: selected,
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
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusCard),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.appTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Icon(icon, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}
