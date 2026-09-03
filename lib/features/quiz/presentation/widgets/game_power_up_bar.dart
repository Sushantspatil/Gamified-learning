import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';

class GamePowerUpAction {
  final String id;
  final String label;
  final String description;
  final int coinCost;
  final IconData icon;
  final bool isUsed;
  final bool isDisabled;
  final VoidCallback onUse;

  const GamePowerUpAction({
    required this.id,
    required this.label,
    required this.description,
    required this.coinCost,
    required this.icon,
    required this.onUse,
    this.isUsed = false,
    this.isDisabled = false,
  });
}

class GamePowerUpBar extends ConsumerStatefulWidget {
  final List<GamePowerUpAction> actions;
  final int? coinBalanceOverride;
  final bool isDisabled;
  final bool isDense;
  final bool showWallet;

  const GamePowerUpBar({
    super.key,
    required this.actions,
    this.coinBalanceOverride,
    this.isDisabled = false,
    this.isDense = false,
    this.showWallet = true,
  });

  @override
  ConsumerState<GamePowerUpBar> createState() => _GamePowerUpBarState();
}

class _GamePowerUpBarState extends ConsumerState<GamePowerUpBar> {
  String? _pendingActionId;

  Future<void> _buyAndUse(GamePowerUpAction action) async {
    if (widget.isDisabled || action.isDisabled || action.isUsed) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PowerUpBuySheet(action: action),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _pendingActionId = action.id);
    final overrideCoins = widget.coinBalanceOverride;
    final didDebit = overrideCoins == null
        ? await ref
              .read(walletControllerProvider.notifier)
              .debit(
                currency: CurrencyType.coins,
                amount: action.coinCost,
                reason: 'In-game power-up: ${action.label}',
              )
        : overrideCoins >= action.coinCost;
    if (!mounted) return;

    setState(() => _pendingActionId = null);
    if (!didDebit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough coins for ${action.label}.')),
      );
      return;
    }

    action.onUse();
  }

  @override
  Widget build(BuildContext context) {
    final walletCoins =
        widget.coinBalanceOverride ??
        ref.watch(walletControllerProvider).valueOrNull?.coins ??
        0;

    return AppCard(
      key: const Key('game_power_up_bar'),
      borderRadius: AppDimensions.radiusLg,
      padding: AppSpacing.paddingSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showWallet) ...[
            Row(
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.coinGold,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$walletCoins coins',
                    style: context.appTextStyles.labelLarge,
                  ),
                ),
                Text('Power-ups', style: context.appTextStyles.labelSmall),
              ],
            ),
            SizedBox(height: widget.isDense ? AppSpacing.xs : AppSpacing.sm),
          ],
          Row(
            children: [
              for (var index = 0; index < widget.actions.length; index++) ...[
                Expanded(
                  child: _PowerUpTile(
                    action: widget.actions[index],
                    isBusy: _pendingActionId == widget.actions[index].id,
                    isDisabled: widget.isDisabled,
                    isDense: widget.isDense,
                    onTap: () => _buyAndUse(widget.actions[index]),
                  ),
                ),
                if (index != widget.actions.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PowerUpTile extends StatelessWidget {
  final GamePowerUpAction action;
  final bool isBusy;
  final bool isDisabled;
  final bool isDense;
  final VoidCallback onTap;

  const _PowerUpTile({
    required this.action,
    required this.isBusy,
    required this.isDisabled,
    required this.isDense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final disabled = isDisabled || action.isDisabled || action.isUsed || isBusy;

    return Tooltip(
      message: action.isUsed ? '${action.label} used' : action.description,
      child: InkWell(
        key: Key('powerup-${action.id}'),
        onTap: disabled ? null : onTap,
        borderRadius: AppDimensions.radiusMd,
        child: Ink(
          height: isDense ? 48 : 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: disabled ? 0.06 : 0.12),
            borderRadius: AppDimensions.radiusMd,
            border: Border.all(
              color: colors.primary.withValues(alpha: disabled ? 0.12 : 0.28),
            ),
          ),
          child: isBusy
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : isDense
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      action.icon,
                      color: disabled ? colors.textMuted : colors.primary,
                      size: 17,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        action.isUsed
                            ? 'Used'
                            : '${action.label} ${action.coinCost}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextStyles.labelSmall.copyWith(
                          color: disabled
                              ? colors.textMuted
                              : colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          action.icon,
                          color: disabled ? colors.textMuted : colors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            action.isUsed ? 'Used' : action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.labelLarge.copyWith(
                              color: disabled
                                  ? colors.textMuted
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: AppColors.coinGold,
                          size: 15,
                        ),
                        Text(
                          '${action.coinCost}',
                          style: context.appTextStyles.labelSmall.copyWith(
                            color: AppColors.coinGold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PowerUpBuySheet extends StatelessWidget {
  final GamePowerUpAction action;

  const _PowerUpBuySheet({required this.action});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: AppDimensions.radiusMd,
                    ),
                    child: Icon(action.icon, color: colors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.label,
                          style: context.appTextStyles.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          action.description,
                          style: context.appTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.coinGold.withValues(alpha: 0.12),
                  borderRadius: AppDimensions.radiusMd,
                  border: Border.all(
                    color: AppColors.coinGold.withValues(alpha: 0.36),
                  ),
                ),
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: AppColors.coinGold,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${action.coinCost} coins',
                        style: context.appTextStyles.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Buy & use',
                leadingIcon: const Icon(Icons.flash_on_rounded),
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
