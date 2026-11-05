import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Monday to Sunday as seven circles: the days of the current streak are
/// ticked and today is ringed.
class StreakWeekRow extends StatelessWidget {
  final int currentStreak;

  const StreakWeekRow({super.key, required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < 7; index++)
          _StreakDayMarker(index: index, currentStreak: currentStreak),
      ],
    );
  }
}

class _StreakDayMarker extends StatelessWidget {
  final int index;
  final int currentStreak;

  const _StreakDayMarker({required this.index, required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final weekdayIndex = DateTime.now().weekday - 1;
    final daysFromToday = weekdayIndex - index;
    final isToday = index == weekdayIndex;
    final isCompleted = daysFromToday >= 0 && daysFromToday < currentStreak;
    final labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final accent = colors.warning;
    final borderColor = isToday
        ? accent
        : isCompleted
        ? accent.withValues(alpha: 0.45)
        : colors.borderStrong;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? accent.withValues(alpha: 0.12)
                : colors.surfaceElevated,
            border: Border.all(color: borderColor, width: isToday ? 2 : 1),
          ),
          child: isCompleted
              ? Icon(Icons.check, color: colors.warning, size: 17)
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          labels[index],
          style: context.appTextStyles.labelSmall.copyWith(
            color: isToday ? colors.textPrimary : colors.textMuted,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
