import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../domain/entities/shop_item.dart';

class ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final String actionLabel;
  final bool isLoading;
  final VoidCallback onTap;

  const ShopItemCard({
    super.key,
    required this.item,
    required this.actionLabel,
    required this.isLoading,
    required this.onTap,
  });

  IconData get _icon {
    switch (item.category) {
      case ShopItemCategory.gems:
        return Icons.diamond;
      case ShopItemCategory.coins:
        return Icons.monetization_on;
      case ShopItemCategory.adGems:
        return Icons.smart_display;
      case ShopItemCategory.powerup:
        return Icons.ac_unit;
    }
  }

  String get _trailingLabel {
    if (item.priceLabel != null) return item.priceLabel!;
    if (item.costCurrency != null && item.costAmount != null) {
      final label = item.costCurrency == CurrencyType.coins ? 'Coins' : 'Gems';
      return '${item.costAmount} $label';
    }
    return 'Free';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(_icon, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: context.appTextStyles.titleMedium),
                Text(item.description, style: context.appTextStyles.bodyMedium),
                Text(_trailingLabel, style: context.appTextStyles.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: isLoading ? null : onTap,
            child: isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
