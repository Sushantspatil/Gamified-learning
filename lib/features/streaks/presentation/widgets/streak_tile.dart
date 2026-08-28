import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../providers/streak_providers.dart';

class StreakTile extends ConsumerWidget {
  const StreakTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakControllerProvider);
    final colors = context.themeColors;

    return Expanded(
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: colors.border),
        ),
        child: streakAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Column(
            children: [
              Icon(Icons.local_fire_department, color: colors.textSecondary),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Streak',
                textAlign: TextAlign.center,
                style: context.appTextStyles.labelSmall,
              ),
            ],
          ),
          data: (streak) => Column(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: AppColors.streakFire,
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedCountText(
                value: streak.currentStreak,
                suffix: ' day${streak.currentStreak == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: context.appTextStyles.labelLarge,
              ),
              Text(
                'Streak',
                textAlign: TextAlign.center,
                style: context.appTextStyles.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
