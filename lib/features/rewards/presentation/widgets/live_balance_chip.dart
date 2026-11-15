import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/rewards_controller.dart';
import 'coin_balance_chip.dart';

/// The player's coin (or, with [gems], gem) balance as a chip that counts to a
/// new number when the balance changes. It is where a reward flies to: the
/// coins from a game on the result screen, the coins from an opened chest.
///
/// It shows the real balance, so a number that has not reached the account yet
/// (the game's coins arrive a moment after the game ends) simply ticks up when
/// it does. With no provider scope (some tests) it shows nothing.
class LiveBalanceChip extends StatelessWidget {
  final bool gems;

  const LiveBalanceChip({super.key, this.gems = false});

  @override
  Widget build(BuildContext context) {
    final hasScope =
        context
            .getElementForInheritedWidgetOfExactType<
              UncontrolledProviderScope
            >() !=
        null;
    if (!hasScope) return const SizedBox.shrink();
    return Consumer(
      builder: (context, ref, _) {
        final amount = ref.watch(
          rewardsProvider.select((s) => gems ? s.gems : s.coins),
        );
        return _Chip(amount: amount, gems: gems);
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final int amount;
  final bool gems;

  const _Chip({required this.amount, required this.gems});

  @override
  Widget build(BuildContext context) {
    final color = gems ? GemBalanceChip.gemColor : AppColors.coinGold;
    final style = context.appTextStyles.labelLarge.copyWith(
      color: context.themeColors.textPrimary,
      fontWeight: FontWeight.w800,
    );
    // The gem number keeps the key of the plain gem chip it replaces on the
    // Chest Box, so the same lookups keep working.
    final valueKey = Key(gems ? 'gem_balance' : 'live_balance_value');
    // With no "begin" the count starts at the balance it is first shown with,
    // then counts from there whenever the balance changes.
    final number = AppMotion.reduceMotion(context)
        ? Text('$amount', key: valueKey, style: style)
        : TweenAnimationBuilder<int>(
            tween: IntTween(end: amount),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                Text('$value', key: valueKey, style: style),
          );

    return Semantics(
      label: '${gems ? 'Gem' : 'Coin'} balance $amount',
      child: DecoratedBox(
        key: Key(gems ? 'live_gems' : 'live_coins'),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: AppDimensions.radiusCircular,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.ms,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                gems ? Icons.diamond_rounded : Icons.monetization_on_rounded,
                size: 20,
                color: color,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              number,
            ],
          ),
        ),
      ),
    );
  }
}
