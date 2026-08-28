import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../domain/entities/learning_path.dart';

class LearningPathCard extends StatelessWidget {
  final LearningPath path;
  final bool isSelected;
  final VoidCallback onTap;

  const LearningPathCard({
    super.key,
    required this.path,
    required this.isSelected,
    required this.onTap,
  });

  String get _difficultyLabel {
    switch (path.difficulty) {
      case LearningPathDifficulty.beginner:
        return 'Beginner';
      case LearningPathDifficulty.intermediate:
        return 'Intermediate';
      case LearningPathDifficulty.advanced:
        return 'Advanced';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusMd,
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: isSelected ? colors.surfaceElevated : colors.cardBackground,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(path.title, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    path.description,
                    style: context.appTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$_difficultyLabel • ${path.topicCount} topics',
                    style: context.appTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
