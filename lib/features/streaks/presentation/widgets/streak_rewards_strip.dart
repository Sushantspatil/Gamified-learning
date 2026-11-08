import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../domain/entities/streak_rewards.dart';
import '../providers/streak_rewards_providers.dart';

/// Under the streak week: a reward ready to collect, or how far the streak is
/// from the next one. Shows nothing until the server has streak rewards.
class StreakRewardsStrip extends ConsumerStatefulWidget {
  const StreakRewardsStrip({super.key});

  @override
  ConsumerState<StreakRewardsStrip> createState() => _StreakRewardsStripState();
}

class _StreakRewardsStripState extends ConsumerState<StreakRewardsStrip> {
  bool _collecting = false;

  Future<void> _collect(StreakMilestone milestone) async {
    if (_collecting) return;
    setState(() => _collecting = true);
    final problem = await ref
        .read(streakRewardsControllerProvider.notifier)
        .claim(milestone.days);
    if (!mounted) return;
    setState(() => _collecting = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(problem ?? '${milestone.rewardLabel} collected!'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final rewards = ref.watch(streakRewardsControllerProvider).valueOrNull;
    if (rewards == null || rewards.milestones.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = context.themeColors;
    final claimable = rewards.claimable;
    final next = rewards.next;

    final Widget content;
    if (claimable != null) {
      // A Wrap, so on a narrow phone (or with large text) the button drops to
      // its own line instead of overflowing.
      content = Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard, color: colors.primary, size: 22),
              const SizedBox(width: AppSpacing.ms),
              Flexible(
                child: Text(
                  '${claimable.days}-day streak reward',
                  style: context.appTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          AppPressable(
            key: Key('collect_streak_${claimable.days}'),
            onTap: _collecting ? null : () => _collect(claimable),
            borderRadius: AppDimensions.radiusCircular,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: AppDimensions.radiusCircular,
              ),
              child: _collecting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Collect ${claimable.rewardLabel}',
                      style: context.appTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      );
    } else if (next != null) {
      final left = next.days - rewards.currentStreak;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            left == 1
                ? '1 more day for ${next.rewardLabel}'
                : '$left more days for ${next.rewardLabel}',
            textAlign: TextAlign.center,
            style: context.appTextStyles.labelLarge.copyWith(
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(
            value: (rewards.currentStreak / next.days).clamp(0.0, 1.0),
            height: 6,
            semanticLabel: 'Progress to the ${next.days}-day streak reward',
          ),
        ],
      );
    } else {
      content = Text(
        'All streak rewards collected. Keep it going!',
        textAlign: TextAlign.center,
        style: context.appTextStyles.labelLarge.copyWith(color: colors.success),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        key: const Key('streak_rewards_strip'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: AppDimensions.radiusMd,
        ),
        child: content,
      ),
    );
  }
}
