import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../domain/entities/chapter.dart';

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;

  const ChapterCard({super.key, required this.chapter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusMd,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chapter ${chapter.order}', style: context.appTextStyles.labelSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(chapter.title, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${chapter.topicCount} topics', style: context.appTextStyles.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
