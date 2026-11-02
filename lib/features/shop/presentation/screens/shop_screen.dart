import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/data/rewards_catalog.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';

enum _ShopTab {
  avatars('Avatars'),
  frames('Profile Frames'),
  powerUps('Power-ups');

  final String label;
  const _ShopTab(this.label);
}

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  _ShopTab _tab = _ShopTab.avatars;

  /// True while a purchase dialog is open, so taps cannot stack purchases.
  bool _busy = false;

  List<ShopProduct> get _products => switch (_tab) {
    _ShopTab.avatars => RewardsCatalog.avatars,
    _ShopTab.frames => RewardsCatalog.frames,
    _ShopTab.powerUps => RewardsCatalog.powerUps,
  };

  Future<void> _buy(ShopProduct product) async {
    if (_busy) return;
    _busy = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.themeColors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusLg),
          title: const Text('Confirm purchase'),
          content: Text(
            'Do you want to purchase ${product.name} for ${product.price} Coins?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm Purchase'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final outcome = ref.read(rewardsProvider.notifier).purchase(product.id);
      final message = switch (outcome) {
        PurchaseOutcome.success =>
          'Purchase successful! ${product.name} is now yours.',
        PurchaseOutcome.notEnoughCoins =>
          'Not enough coins. Earn more coins to purchase this item.',
        PurchaseOutcome.alreadyOwned => 'You already own ${product.name}.',
        PurchaseOutcome.unavailable => '${product.name} is not available yet.',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final state = ref.watch(rewardsProvider);
    final products = _products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: const [
          CoinBalanceChip(),
          SizedBox(width: AppSpacing.xs),
          ThemeModeMenu(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView.builder(
              padding: AppSpacing.paddingMd,
              itemCount: products.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tab in _ShopTab.values)
                          ChoiceChip(
                            label: Text(tab.label),
                            selected: _tab == tab,
                            showCheckmark: false,
                            selectedColor: colors.primary,
                            side: BorderSide(color: colors.border),
                            labelStyle: styles.badge.copyWith(
                              color: _tab == tab
                                  ? colors.primaryForeground
                                  : colors.textPrimary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppDimensions.radiusCircular,
                            ),
                            onSelected: (_) => setState(() => _tab = tab),
                          ),
                      ],
                    ),
                  );
                }
                final product = products[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ProductTile(
                    key: ValueKey(product.id),
                    product: product,
                    state: state,
                    onBuy: () => _buy(product),
                    onEquip: () =>
                        ref.read(rewardsProvider.notifier).equip(product.id),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ShopProduct product;
  final RewardsState state;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _ProductTile({
    super.key,
    required this.product,
    required this.state,
    required this.onBuy,
    required this.onEquip,
  });

  bool get _owned => switch (product.kind) {
    ProductKind.avatar => state.ownedAvatars.contains(product.id),
    ProductKind.frame => state.ownedFrames.contains(product.id),
    ProductKind.powerUp => false,
  };

  bool get _equipped =>
      state.equippedAvatar == product.id || state.equippedFrame == product.id;

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final isPowerUp = product.kind == ProductKind.powerUp;
    final quantity = isPowerUp ? state.powerUpCount(product.powerUp!) : 0;

    final String subtitle;
    if (isPowerUp) {
      subtitle = product.comingSoon
          ? (product.description ?? '')
          : 'You have: $quantity';
    } else if (_equipped) {
      subtitle = 'Equipped';
    } else if (_owned) {
      subtitle = 'Owned';
    } else {
      subtitle = '';
    }

    Widget action;
    if (product.comingSoon) {
      action = const _TileButton(label: 'Coming soon');
    } else if (_owned) {
      action = _TileButton(
        label: _equipped ? 'Equipped' : 'Equip',
        onPressed: _equipped ? null : onEquip,
      );
    } else {
      action = _TileButton(label: 'Buy', onPressed: onBuy);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(
          color: _equipped ? colors.success : colors.border,
          width: _equipped ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.ms),
        child: Row(
          children: [
            _Preview(product: product),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: styles.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 16,
                        color: AppColors.coinGold,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${product.price} Coins',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: styles.caption.copyWith(
                        color: _owned || _equipped
                            ? colors.success
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            action,
          ],
        ),
      ),
    );
  }
}

/// Avatar icon, frame ring, or token icon.
class _Preview extends StatelessWidget {
  final ShopProduct product;

  const _Preview({required this.product});

  @override
  Widget build(BuildContext context) {
    final isFrame = product.kind == ProductKind.frame;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: product.color.withValues(alpha: isFrame ? 0.08 : 0.16),
        border: Border.all(color: product.color, width: isFrame ? 5 : 1.5),
      ),
      child: Icon(
        isFrame ? Icons.person_rounded : product.icon,
        color: product.color,
        size: 28,
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _TileButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.ms),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusSm),
        ),
        child: Text(label, style: context.appTextStyles.badge),
      ),
    );
  }
}
