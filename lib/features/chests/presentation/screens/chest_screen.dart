import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/success_pop.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../domain/entities/chest_type.dart';
import '../providers/chest_providers.dart';

class ChestScreen extends ConsumerStatefulWidget {
  final ChestType type;

  const ChestScreen({super.key, required this.type});

  @override
  ConsumerState<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends ConsumerState<ChestScreen> {
  bool _isOpening = false;

  String get _title =>
      widget.type == ChestType.daily ? 'Daily Chest' : 'Ad Chest';

  Future<void> _open() async {
    setState(() => _isOpening = true);
    final result = await ref
        .read(chestControllerProvider(widget.type).notifier)
        .open(widget.type);
    if (!mounted) return;
    setState(() => _isOpening = false);

    if (result == null) return;
    HapticFeedback.mediumImpact();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chest Opened!'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SuccessPop(
              active: true,
              child: Icon(
                result.currency == CurrencyType.coins
                    ? Icons.monetization_on
                    : Icons.diamond,
                color: result.currency == CurrencyType.coins
                    ? AppColors.coinGold
                    : AppColors.gemCyan,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '+${result.amount} ${result.currency == CurrencyType.coins ? 'Coins' : 'Gems'}',
              style: context.appTextStyles.titleLarge,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nice!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableAsync = ref.watch(chestControllerProvider(widget.type));

    return Scaffold(
      appBar: AppBar(title: Text(_title), actions: const [ThemeModeMenu()]),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.card_giftcard,
                  size: 96,
                  color: AppColors.coinGold,
                ),
                const SizedBox(height: AppSpacing.lg),
                availableAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stackTrace) => Text(
                    'Could not check chest availability.',
                    style: context.appTextStyles.bodyLarge,
                  ),
                  data: (isAvailable) {
                    if (!isAvailable) {
                      return Text(
                        widget.type == ChestType.daily
                            ? 'Come back tomorrow for your next daily chest.'
                            : 'Not available right now.',
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.bodyLarge,
                      );
                    }
                    return AppButton(
                      label: widget.type == ChestType.daily
                          ? 'Open Chest'
                          : 'Watch Ad to Open',
                      isLoading: _isOpening,
                      onPressed: _open,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
