import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../rewards_hub/domain/rewards_models.dart';
import '../../../rewards_hub/presentation/providers/rewards_providers.dart';

enum ProductAction { buy, equip, equipped, maxed }

ProductAction productActionFor(ShopProduct product, RewardsState state) {
  if (product.isConsumable) {
    return state.powerUpCount(product.powerUp!) >= product.maxQuantity
        ? ProductAction.maxed
        : ProductAction.buy;
  }
  if (!state.ownedItemIds.contains(product.id)) return ProductAction.buy;
  if (!product.isEquippable) return ProductAction.equipped;
  final equippedId = product.category == ShopCategory.avatars
      ? state.equippedAvatarId
      : state.equippedFrameId;
  return equippedId == product.id
      ? ProductAction.equipped
      : ProductAction.equip;
}

String productActionLabel(ProductAction action) => switch (action) {
  ProductAction.buy => 'Buy',
  ProductAction.equip => 'Equip',
  ProductAction.equipped => 'Equipped',
  ProductAction.maxed => 'Max',
};

/// Artwork block shared by the grid card and the details sheet.
class ProductPreview extends StatelessWidget {
  final ShopProduct product;
  final double height;

  const ProductPreview({super.key, required this.product, this.height = 84});

  @override
  Widget build(BuildContext context) {
    final isFrame = product.category == ShopCategory.frames;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppDimensions.radiusMd,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            product.color.withValues(alpha: 0.28),
            product.color.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Center(
          child: Container(
            width: height * 0.66,
            height: height * 0.66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: product.color.withValues(alpha: 0.18),
              border: Border.all(
                color: product.color,
                width: isFrame ? 4 : 1.5,
              ),
            ),
            child: Icon(
              product.icon,
              color: product.color,
              size: height * 0.34,
            ),
          ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final ShopProduct product;
  final RewardsState state;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const ProductCard({
    super.key,
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
    final quantity = product.isConsumable
        ? state.powerUpCount(product.powerUp!)
        : 0;
    final owned = product.isConsumable
        ? quantity > 0
        : state.ownedItemIds.contains(product.id);

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusCard,
          border: Border.all(
            color: action == ProductAction.equipped
                ? colors.success.withValues(alpha: 0.6)
                : colors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ProductPreview(product: product),
                  if (owned)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Tag(
                        label: product.isConsumable
                            ? '×$quantity'
                            : action == ProductAction.equipped
                            ? 'Equipped'
                            : 'Owned',
                        color: colors.success,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.labelLarge,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.caption.copyWith(color: colors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    size: 16,
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
                  const SizedBox(width: AppSpacing.xs),
                  _CardActionButton(action: action, onPressed: onAction),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppDimensions.radiusSm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: context.appTextStyles.badge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final ProductAction action;
  final VoidCallback onPressed;

  const _CardActionButton({required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final enabled =
        action == ProductAction.buy || action == ProductAction.equip;
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(0, 32),
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryForeground,
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusSm),
        ),
        child: Text(
          productActionLabel(action),
          style: context.appTextStyles.badge.copyWith(
            color: enabled ? colors.primaryForeground : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
