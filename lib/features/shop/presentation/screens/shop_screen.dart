import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards_hub/data/rewards_mock_data.dart';
import '../../../rewards_hub/domain/rewards_models.dart';
import '../../../rewards_hub/presentation/providers/rewards_providers.dart';
import '../../../rewards_hub/presentation/widgets/rewards_common_widgets.dart';
import '../widgets/shop_item_card.dart';

String _categoryLabel(ShopCategory category) => switch (category) {
  ShopCategory.featured => 'Featured',
  ShopCategory.avatars => 'Avatars',
  ShopCategory.frames => 'Frames',
  ShopCategory.powerUps => 'Power-ups',
};

/// Purchase / equip flow shared by the grid, the hero and the details sheet.
Future<void> _runProductAction(
  BuildContext context,
  WidgetRef ref,
  ShopProduct product,
) async {
  final state = ref.read(rewardsProvider);
  switch (productActionFor(product, state)) {
    case ProductAction.equip:
      ref.read(rewardsProvider.notifier).equip(product.id);
    case ProductAction.buy:
      await _confirmAndBuy(context, ref, product);
    case ProductAction.equipped:
    case ProductAction.maxed:
      break;
  }
}

Future<void> _confirmAndBuy(
  BuildContext context,
  WidgetRef ref,
  ShopProduct product,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _PurchaseDialog(product: product),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.maybeOf(context);
  final notifier = ref.read(rewardsProvider.notifier);
  final outcome = notifier.purchase(product.id);
  messenger.hideCurrentSnackBar();

  switch (outcome) {
    case PurchaseOutcome.success:
      ref.read(gameAudioServiceProvider).play(GameSound.coinReward);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${product.name} purchased.'),
          action: product.isEquippable
              ? SnackBarAction(
                  label: 'Equip',
                  onPressed: () => notifier.equip(product.id),
                )
              : null,
        ),
      );
    case PurchaseOutcome.insufficientCoins:
      final missing = product.price - ref.read(rewardsProvider).coins;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You need $missing more coins for ${product.name}. '
            'Spin the wheel or open a chest to earn some.',
          ),
          action: router == null
              ? null
              : SnackBarAction(
                  label: 'Spin',
                  onPressed: () => router.push(RouteNames.spinWheel),
                ),
        ),
      );
    case PurchaseOutcome.alreadyOwned:
      messenger.showSnackBar(
        SnackBar(content: Text('You already own ${product.name}.')),
      );
    case PurchaseOutcome.maxStack:
      messenger.showSnackBar(
        SnackBar(
          content: Text('You already hold the maximum of ${product.name}.'),
        ),
      );
  }
}

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  ShopCategory _category = ShopCategory.featured;

  static final ShopProduct _hero = RewardsMockData.shopProducts.firstWhere(
    (p) => p.featured,
  );

  List<ShopProduct> get _visibleProducts {
    return RewardsMockData.shopProducts.where((p) {
      if (_category == ShopCategory.featured) {
        return p.featured && p.id != _hero.id;
      }
      return p.category == _category;
    }).toList();
  }

  void _openDetails(ShopProduct product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ProductSheet(productId: product.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final state = ref.watch(rewardsProvider);
    final products = _visibleProducts;
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );

    final ownedProducts = RewardsMockData.shopProducts
        .where(
          (p) => p.isConsumable
              ? state.powerUpCount(p.powerUp!) > 0
              : state.ownedItemIds.contains(p.id),
        )
        .toList();

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
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _HeroBanner(
                        product: _hero,
                        state: state,
                        onTap: () => _openDetails(_hero),
                        onAction: () => _runProductAction(context, ref, _hero),
                      ),
                      if (ownedProducts.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text('Your items', style: styles.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        _OwnedStrip(
                          products: ownedProducts,
                          state: state,
                          onTap: _openDetails,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      // Wraps instead of scrolling so no tab is ever clipped on
                      // narrow screens or with large text.
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final category in ShopCategory.values)
                            ChoiceChip(
                              label: Text(_categoryLabel(category)),
                              selected: _category == category,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                              selectedColor: colors.primary,
                              labelStyle: styles.badge.copyWith(
                                color: _category == category
                                    ? colors.primaryForeground
                                    : colors.textPrimary,
                              ),
                              showCheckmark: false,
                              side: BorderSide(color: colors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppDimensions.radiusCircular,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisSpacing: AppSpacing.ms,
                      crossAxisSpacing: AppSpacing.ms,
                      mainAxisExtent: 226 * textScale,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        key: ValueKey('product-${product.id}'),
                        product: product,
                        state: state,
                        onTap: () => _openDetails(product),
                        onAction: () =>
                            _runProductAction(context, ref, product),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final ShopProduct product;
  final RewardsState state;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const _HeroBanner({
    required this.product,
    required this.state,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final action = productActionFor(product, state);

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppDimensions.radiusCard,
          border: Border.all(color: product.color.withValues(alpha: 0.5)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              product.color.withValues(alpha: 0.28),
              colors.cardBackground,
            ],
          ),
        ),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: ProductPreview(product: product, height: 84),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FEATURED',
                      style: styles.badge.copyWith(color: product.color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      style: styles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      style: styles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: AppColors.coinGold,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${product.price}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: styles.labelLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 34,
                          child: FilledButton(
                            onPressed:
                                action == ProductAction.buy ||
                                    action == ProductAction.equip
                                ? onAction
                                : null,
                            child: Text(productActionLabel(action)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnedStrip extends StatelessWidget {
  final List<ShopProduct> products;
  final RewardsState state;
  final ValueChanged<ShopProduct> onTap;

  const _OwnedStrip({
    required this.products,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final product = products[index];
          final action = productActionFor(product, state);
          final detail = product.isConsumable
              ? '×${state.powerUpCount(product.powerUp!)}'
              : action == ProductAction.equipped
              ? 'Equipped'
              : 'Owned';
          return AppPressable(
            onTap: () => onTap(product),
            borderRadius: AppDimensions.radiusMd,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: AppDimensions.radiusMd,
                border: Border.all(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    RewardIconBadge(
                      icon: product.icon,
                      color: product.color,
                      size: 36,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: styles.badge,
                          ),
                        ),
                        Text(
                          detail,
                          style: styles.caption.copyWith(color: colors.success),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PurchaseDialog extends ConsumerWidget {
  final ShopProduct product;

  const _PurchaseDialog({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(rewardsProvider.select((s) => s.coins));
    final styles = context.appTextStyles;
    final colors = context.themeColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusLg),
      title: Text('Buy ${product.name}?', style: styles.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RewardIconBadge(icon: product.icon, color: product.color),
              const SizedBox(width: AppSpacing.ms),
              Expanded(
                child: Text(
                  '${product.price} coins',
                  style: styles.headingSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your balance: $coins coins',
            style: styles.bodySmall.copyWith(color: colors.textSecondary),
          ),
          if (coins < product.price) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You are ${product.price - coins} coins short.',
              style: styles.bodySmall.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _ProductSheet extends ConsumerWidget {
  final String productId;

  const _ProductSheet({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = RewardsMockData.productById(productId)!;
    final state = ref.watch(rewardsProvider);
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final action = productActionFor(product, state);
    final enabled =
        action == ProductAction.buy || action == ProductAction.equip;
    final quantity = product.isConsumable
        ? state.powerUpCount(product.powerUp!)
        : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductPreview(product: product, height: 132),
          const SizedBox(height: AppSpacing.md),
          Text(
            _categoryLabel(product.category).toUpperCase(),
            style: styles.badge.copyWith(color: product.color),
          ),
          const SizedBox(height: 2),
          Text(product.name, style: styles.headingMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            product.description,
            style: styles.body.copyWith(color: colors.textSecondary),
          ),
          if (product.isConsumable) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              quantity > 0
                  ? 'You have $quantity (max ${product.maxQuantity}).'
                  : 'Single-use. You can hold up to ${product.maxQuantity}.',
              style: styles.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: AppColors.coinGold,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('${product.price}', style: styles.headingSmall),
              const Spacer(),
              Text(
                'Balance: ${state.coins}',
                style: styles.bodySmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: action == ProductAction.buy
                ? 'Buy for ${product.price} coins'
                : productActionLabel(action),
            onPressed: enabled
                ? () => _runProductAction(context, ref, product)
                : null,
          ),
        ],
      ),
    );
  }
}
