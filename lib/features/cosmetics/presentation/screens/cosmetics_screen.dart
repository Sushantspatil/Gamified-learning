import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../domain/entities/cosmetic_item.dart';
import '../cosmetic_color_catalog.dart';
import '../providers/cosmetics_providers.dart';

class CosmeticsScreen extends ConsumerStatefulWidget {
  const CosmeticsScreen({super.key});

  @override
  ConsumerState<CosmeticsScreen> createState() => _CosmeticsScreenState();
}

class _CosmeticsScreenState extends ConsumerState<CosmeticsScreen> {
  String? _busyItemId;

  Future<void> _handleTap(
    CosmeticItem item,
    bool isOwned,
    bool isEquipped,
  ) async {
    if (isEquipped) return;
    setState(() => _busyItemId = item.id);

    if (isOwned) {
      await ref.read(cosmeticsControllerProvider.notifier).equip(item.id);
      HapticFeedback.selectionClick();
    } else {
      final result = await ref
          .read(cosmeticsControllerProvider.notifier)
          .purchase(item);
      if (mounted && result == CosmeticPurchaseResult.insufficientFunds) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Not enough coins.')));
      } else if (result == CosmeticPurchaseResult.success) {
        HapticFeedback.mediumImpact();
      }
    }

    if (!mounted) return;
    setState(() => _busyItemId = null);
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(cosmeticsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cosmetics'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load cosmetics.',
                    style: context.appTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Retry',
                    onPressed: () =>
                        ref.invalidate(cosmeticsControllerProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (state) {
            if (state.catalog.isEmpty) {
              return Center(
                child: Text(
                  'No cosmetics available yet.',
                  style: context.appTextStyles.bodyLarge,
                ),
              );
            }

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                for (final item in state.catalog)
                  _CosmeticCard(
                    item: item,
                    isOwned: state.ownedIds.contains(item.id),
                    isEquipped: state.equippedId == item.id,
                    isBusy: _busyItemId == item.id,
                    onTap: () => _handleTap(
                      item,
                      state.ownedIds.contains(item.id),
                      state.equippedId == item.id,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  final CosmeticItem item;
  final bool isOwned;
  final bool isEquipped;
  final bool isBusy;
  final VoidCallback onTap;

  const _CosmeticCard({
    required this.item,
    required this.isOwned,
    required this.isEquipped,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final color =
        CosmeticColorCatalog.colorFor(item.colorKey) ?? AppColors.primary;
    final label = isEquipped
        ? 'Equipped'
        : (isOwned ? 'Equip' : '${item.costCoins} Coins');

    return Container(
      key: ValueKey('cosmetic-${item.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(item.name, style: context.appTextStyles.titleMedium),
          ),
          FilledButton(
            onPressed: isEquipped || isBusy ? null : onTap,
            child: isBusy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          ),
        ],
      ),
    );
  }
}
