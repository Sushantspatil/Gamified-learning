import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../providers/wallet_providers.dart';
import '../widgets/transaction_tile.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletControllerProvider);
    final historyAsync = ref.watch(transactionHistoryProvider);
    final colors = context.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.paddingMd,
          children: [
            balanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(
                'Could not load your balance.',
                style: context.appTextStyles.bodyLarge,
              ),
              data: (balance) => Container(
                width: double.infinity,
                padding: AppSpacing.paddingLg,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: AppDimensions.radiusMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BalanceStat(
                      icon: Icons.monetization_on,
                      color: AppColors.coinGold,
                      label: 'Coins',
                      value: balance.coins,
                    ),
                    _BalanceStat(
                      icon: Icons.diamond,
                      color: AppColors.gemCyan,
                      label: 'Gems',
                      value: balance.gems,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Transaction History',
              style: context.appTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load transaction history.',
                    style: context.appTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Retry',
                    onPressed: () => ref.invalidate(transactionHistoryProvider),
                  ),
                ],
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Text(
                    'No transactions yet.',
                    style: context.appTextStyles.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final transaction in transactions)
                      TransactionTile(transaction: transaction),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;

  const _BalanceStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: AppSpacing.xs),
        AnimatedCountText(
          value: value,
          style: context.appTextStyles.displayMedium,
        ),
        Text(label, style: context.appTextStyles.bodyMedium),
      ],
    );
  }
}
