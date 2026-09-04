import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../domain/entities/shop_item.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_item_card.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String? _purchasingItemId;

  Future<void> _handleTap(ShopItem item) async {
    if (item.priceLabel != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Buy ${item.title}?'),
          content: Text(
            'This is a demo purchase for ${item.priceLabel} — no real payment gateway is '
            'configured, so no payment will actually be processed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Buy'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _purchase(item);
  }

  Future<void> _purchase(ShopItem item) async {
    setState(() => _purchasingItemId = item.id);
    final result = await ref
        .read(shopPurchaseControllerProvider.notifier)
        .purchase(item);
    if (!mounted) return;
    setState(() => _purchasingItemId = null);

    final message = switch (result) {
      PurchaseResult.success when item.category == ShopItemCategory.powerup =>
        '${item.title} purchased!',
      PurchaseResult.success =>
        'You received ${item.grantsAmount} ${item.grantsCurrency == CurrencyType.coins ? 'Coins' : 'Gems'}!',
      PurchaseResult.insufficientFunds =>
        'Not enough ${item.costCurrency == CurrencyType.coins ? 'coins' : 'gems'}.',
    };
    if (result == PurchaseResult.success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(shopItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load the shop.',
                    style: context.appTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Retry',
                    onPressed: () => ref.invalidate(shopItemsProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (items) {
            final gems = items
                .where((i) => i.category == ShopItemCategory.gems)
                .toList();
            final coins = items
                .where((i) => i.category == ShopItemCategory.coins)
                .toList();
            final adGems = items
                .where((i) => i.category == ShopItemCategory.adGems)
                .toList();
            final powerups = items
                .where((i) => i.category == ShopItemCategory.powerup)
                .toList();

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                _SectionHeader('Gems'),
                for (final item in gems)
                  ShopItemCard(
                    item: item,
                    actionLabel: 'Buy',
                    isLoading: _purchasingItemId == item.id,
                    onTap: () => _handleTap(item),
                  ),
                const SizedBox(height: AppSpacing.md),
                _SectionHeader('Coins'),
                for (final item in coins)
                  ShopItemCard(
                    item: item,
                    actionLabel: 'Buy',
                    isLoading: _purchasingItemId == item.id,
                    onTap: () => _handleTap(item),
                  ),
                const SizedBox(height: AppSpacing.md),
                _SectionHeader('Ad Gems'),
                for (final item in adGems)
                  ShopItemCard(
                    item: item,
                    actionLabel: 'Watch Ad',
                    isLoading: _purchasingItemId == item.id,
                    onTap: () => _handleTap(item),
                  ),
                const SizedBox(height: AppSpacing.md),
                _SectionHeader('Powerups'),
                for (final item in powerups)
                  ShopItemCard(
                    item: item,
                    actionLabel: 'Buy',
                    isLoading: _purchasingItemId == item.id,
                    onTap: () => _handleTap(item),
                  ),
                const SizedBox(height: AppSpacing.md),
                _SectionHeader('Chests & Spin Wheel'),
                _NavTile(
                  icon: Icons.card_giftcard,
                  title: 'Daily Chest',
                  onTap: () => context.push(RouteNames.chestPath('daily')),
                ),
                _NavTile(
                  icon: Icons.ondemand_video,
                  title: 'Ad Chest',
                  onTap: () => context.push(RouteNames.chestPath('ad')),
                ),
                _NavTile(
                  icon: Icons.casino,
                  title: 'Spin Wheel',
                  onTap: () => context.push(RouteNames.spinWheel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title, style: context.appTextStyles.titleMedium),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title, style: context.appTextStyles.bodyLarge),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
