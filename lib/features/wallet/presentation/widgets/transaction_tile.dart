import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/currency_type.dart';
import '../../domain/entities/wallet_transaction.dart';

class TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == TransactionDirection.credit;
    final colors = context.themeColors;
    final currencyLabel = transaction.currency == CurrencyType.coins
        ? 'Coins'
        : 'Gems';
    final sign = isCredit ? '+' : '-';

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
          Icon(
            isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: isCredit ? colors.success : colors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.reason,
                  style: context.appTextStyles.bodyLarge,
                ),
                Text(
                  '${transaction.createdAt.year}-${transaction.createdAt.month.toString().padLeft(2, '0')}-${transaction.createdAt.day.toString().padLeft(2, '0')}',
                  style: context.appTextStyles.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            '$sign${transaction.amount} $currencyLabel',
            style: context.appTextStyles.labelLarge,
          ),
        ],
      ),
    );
  }
}
