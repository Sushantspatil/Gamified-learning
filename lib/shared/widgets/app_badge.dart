import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/app_typography.dart';

enum AppBadgeVariant {
  neutral,
  primary,
  success,
  warning,
  error,
  subjectAccent,
}

enum AppSubjectAccent { accountancy, businessStudies, economics }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final AppSubjectAccent? subjectAccent;
  final Color? accentColor;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.subjectAccent,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final accent = _accent(colors);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: variant == AppBadgeVariant.neutral ? 0.08 : 0.12,
        ),
        borderRadius: AppDimensions.radiusCircular,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: AppTypography.badge.copyWith(
            color: variant == AppBadgeVariant.neutral
                ? colors.textSecondary
                : accent,
          ),
        ),
      ),
    );
  }

  Color _accent(AppThemeColors colors) {
    if (accentColor != null) return accentColor!;

    return switch (variant) {
      AppBadgeVariant.neutral => colors.textSecondary,
      AppBadgeVariant.primary => colors.primary,
      AppBadgeVariant.success => colors.success,
      AppBadgeVariant.warning => colors.warning,
      AppBadgeVariant.error => colors.error,
      AppBadgeVariant.subjectAccent => switch (subjectAccent) {
        AppSubjectAccent.businessStudies => colors.subjectBusinessStudies,
        AppSubjectAccent.economics => colors.subjectEconomics,
        AppSubjectAccent.accountancy || null => colors.subjectAccountancy,
      },
    };
  }
}
