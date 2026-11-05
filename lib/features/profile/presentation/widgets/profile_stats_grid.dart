import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';

/// Four numbers that matter, as tiles: streak, coins, gems and level. Coins
/// and gems open the wallet.
class ProfileStatsGrid extends StatelessWidget {
  final int streak;
  final int coins;
  final int gems;
  final int level;
  final VoidCallback onWallet;

  const ProfileStatsGrid({
    super.key,
    required this.streak,
    required this.coins,
    required this.gems,
    required this.level,
    required this.onWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.streakFire,
                value: streak,
                label: 'Day streak',
              ),
            ),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: _StatTile(
                icon: Icons.monetization_on_rounded,
                color: AppColors.coinGold,
                value: coins,
                label: 'Coins',
                onTap: onWallet,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.ms),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.diamond_rounded,
                color: AppColors.gemCyan,
                value: gems,
                label: 'Gems',
                onTap: onWallet,
              ),
            ),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: _StatTile(
                icon: Icons.bolt_rounded,
                color: AppColors.xpPurple,
                value: level,
                label: 'Level',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;

    final tile = AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.ms,
        vertical: AppSpacing.ms,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedCountText(
                    value: value,
                    style: styles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: tile,
    );
  }
}
