import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/equipped_cosmetics.dart';
import '../../application/rewards_controller.dart';

/// The shared coin balance, shown at the top of every rewards screen.
class CoinBalanceChip extends ConsumerWidget {
  const CoinBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(rewardsProvider.select((s) => s.coins));
    return Semantics(
      label: 'Coin balance $coins',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.coinGold.withValues(alpha: 0.14),
          borderRadius: AppDimensions.radiusCircular,
          border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.ms,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                size: 20,
                color: AppColors.coinGold,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                '$coins',
                key: const Key('coin_balance'),
                style: context.appTextStyles.labelLarge.copyWith(
                  color: context.themeColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gem balance (gems come from the Galaxy chest).
class GemBalanceChip extends ConsumerWidget {
  static const Color gemColor = Color(0xFFB57BFF);

  const GemBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gems = ref.watch(rewardsProvider.select((s) => s.gems));
    return Semantics(
      label: 'Gem balance $gems',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gemColor.withValues(alpha: 0.14),
          borderRadius: AppDimensions.radiusCircular,
          border: Border.all(color: gemColor.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.ms,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond_rounded, size: 20, color: gemColor),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                '$gems',
                key: const Key('gem_balance'),
                style: context.appTextStyles.labelLarge.copyWith(
                  color: context.themeColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple one-message dialog used for rewards and purchase results.
///
/// With [mascot] the 3D character cheers above the message (the icon shows
/// while it loads, and stays if 3D cannot run).
Future<void> showRewardDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.celebration_rounded,
  bool mascot = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: context.themeColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusLg),
      icon: mascot
          ? Character3dView(
              width: 140,
              height: 130,
              state: Character3dState.idle,
              initialAction: Character3dAction.cheer,
              cosmetics: equippedCosmetics(context),
              fallback: Icon(icon, size: 40, color: AppColors.coinGold),
            )
          : Icon(icon, size: 40, color: AppColors.coinGold),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: context.appTextStyles.headingSmall,
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: context.appTextStyles.body,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
