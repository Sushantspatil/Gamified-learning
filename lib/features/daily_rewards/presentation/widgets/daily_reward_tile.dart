import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/success_pop.dart';
import '../providers/daily_reward_providers.dart';

class DailyRewardTile extends ConsumerWidget {
  const DailyRewardTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardAsync = ref.watch(dailyRewardControllerProvider);
    final colors = context.themeColors;

    return Expanded(
      child: AppPressable(
        onTap: () {
          final reward = rewardAsync.valueOrNull;
          if (reward != null && !reward.claimedToday) {
            ref.read(dailyRewardControllerProvider.notifier).claim();
            HapticFeedback.mediumImpact();
          }
        },
        borderRadius: AppDimensions.radiusMd,
        child: Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: AppDimensions.radiusMd,
            border: Border.all(color: colors.border),
          ),
          child: rewardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Column(
              children: [
                Icon(Icons.card_giftcard, color: colors.textSecondary),
                const SizedBox(height: AppSpacing.xs),
                Text('Daily Reward', textAlign: TextAlign.center, style: context.appTextStyles.labelSmall),
              ],
            ),
            data: (reward) {
              if (reward == null) {
                return Column(
                  children: [
                    Icon(Icons.card_giftcard, color: colors.textSecondary),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Daily Reward', textAlign: TextAlign.center, style: context.appTextStyles.labelSmall),
                  ],
                );
              }

              return Column(
                children: [
                  SuccessPop(
                    active: reward.claimedToday,
                    child: Icon(
                      reward.claimedToday ? Icons.check_circle : Icons.card_giftcard,
                      color: reward.claimedToday ? colors.success : AppColors.coinGold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    reward.claimedToday ? 'Claimed' : '+${reward.coins}',
                    textAlign: TextAlign.center,
                    style: context.appTextStyles.labelLarge,
                  ),
                  Text('Daily Reward', textAlign: TextAlign.center, style: context.appTextStyles.labelSmall),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
