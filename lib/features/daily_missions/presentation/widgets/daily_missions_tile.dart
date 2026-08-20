import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../providers/daily_mission_providers.dart';

class DailyMissionsTile extends ConsumerWidget {
  const DailyMissionsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(dailyMissionsControllerProvider);
    final colors = context.themeColors;

    return Expanded(
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: colors.border),
        ),
        child: missionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Column(
            children: [
              Icon(Icons.checklist, color: colors.textSecondary),
              const SizedBox(height: AppSpacing.xs),
              Text('Missions', textAlign: TextAlign.center, style: context.appTextStyles.labelSmall),
            ],
          ),
          data: (missions) {
            final mission = missions.isEmpty ? null : missions.first;
            final isCompleted = mission?.isCompleted ?? false;

            return Column(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.checklist,
                  color: isCompleted ? colors.success : colors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  mission == null
                      ? 'No missions'
                      : '${mission.progressCount}/${mission.targetCount}',
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.labelLarge,
                ),
                Text('Daily Missions', textAlign: TextAlign.center, style: context.appTextStyles.labelSmall),
              ],
            );
          },
        ),
      ),
    );
  }
}
