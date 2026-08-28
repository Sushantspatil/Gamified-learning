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
    final isPodium = entry.rank <= 3;
    final rankColor = switch (entry.rank) {
      1 => AppColors.accentGold,
      2 => colors.secondary,
      3 => colors.violet,
      _ => colors.textSecondary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            entry.isCurrentUser
                ? colors.primary.withValues(alpha: 0.14)
                : colors.cardBackground,
            isPodium
                ? rankColor.withValues(alpha: 0.12)
                : colors.surfaceElevated.withValues(alpha: 0.70),
          ],
        ),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(
          color: entry.isCurrentUser
              ? colors.primary
              : isPodium
              ? rankColor.withValues(alpha: 0.40)
              : colors.border,
          width: entry.isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank}',
              style: context.appTextStyles.labelLarge.copyWith(
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.surfaceElevated,
            child: Icon(
              AvatarCatalog.iconFor(entry.avatarId),
              size: 18,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.isCurrentUser
                  ? '${entry.displayName} (You)'
                  : entry.displayName,
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
