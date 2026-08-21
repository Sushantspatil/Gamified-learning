import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/app_typography.dart';

class AppEmptyState extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? description;
  final Widget? action;

  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: colors.textMuted, size: 32),
                child: icon!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              style: context.appTextStyles.title,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: context.appTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
