import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../profile/presentation/avatar_catalog.dart';
import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;

  const LeaderboardTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? colors.surfaceElevated : colors.cardBackground,
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(
          color: entry.isCurrentUser ? colors.primary : colors.border,
          width: entry.isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#${entry.rank}', style: context.appTextStyles.labelLarge),
          ),
          const SizedBox(width: AppSpacing.sm),
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.surfaceElevated,
            child: Icon(AvatarCatalog.iconFor(entry.avatarId), size: 18, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.isCurrentUser ? '${entry.displayName} (You)' : entry.displayName,
              style: context.appTextStyles.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.bolt, color: AppColors.xpPurple, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text('${entry.xp} XP', style: context.appTextStyles.labelLarge),
        ],
      ),
    );
  }
}
