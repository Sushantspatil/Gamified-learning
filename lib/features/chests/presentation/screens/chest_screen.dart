import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../widgets/chest_art.dart';

class ChestScreen extends ConsumerStatefulWidget {
  const ChestScreen({super.key});

  @override
  ConsumerState<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends ConsumerState<ChestScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  Future<void> _openChest() async {
    if (_opening || !ref.read(rewardsProvider).chestReady) return;
    _opening = true; // lock first so repeated taps do nothing
    setState(() {});
    _open.duration = AppMotion.reduceMotion(context)
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 1200);
    await _open.forward(from: 0);
    if (!mounted) return; // nothing was paid; the chest stays ready
    final opened = ref.read(rewardsProvider.notifier).openChest();
    setState(() => _opening = false);
    _open.value = 0;
    if (!opened) return;
    await showRewardDialog(
      context,
      title: 'Chest opened!',
      message: 'You received ${RewardsState.chestReward} Coins.',
      icon: Icons.inventory_2_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final progress = ref.watch(rewardsProvider.select((s) => s.chestProgress));
    final ready = progress >= RewardsState.chestTarget;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chest Box'),
        actions: const [
          CoinBalanceChip(),
          SizedBox(width: AppSpacing.xs),
          ThemeModeMenu(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: AppSpacing.paddingMd,
              children: [
                AppCard(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    children: [
                      ChestArt(
                        // Closed while locked, lid ajar once ready; fully opens on tap.
                        open: _opening
                            ? _open
                            : AlwaysStoppedAnimation<double>(
                                ready ? 0.55 : 0.0,
                              ),
                        color: ready
                            ? const Color(0xFFFFB82E)
                            : const Color(0xFFA9B8CC),
                        colorDark: ready
                            ? const Color(0xFFB27A00)
                            : const Color(0xFF5E6E85),
                        dimmed: !ready,
                        size: 120,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Treasure Chest', style: styles.headingMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        ready
                            ? 'Your chest is ready!'
                            : 'Complete 3 quizzes to unlock your chest.',
                        textAlign: TextAlign.center,
                        style: styles.bodyLarge.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppProgressBar(
                              value: progress / RewardsState.chestTarget,
                              semanticLabel: 'Chest progress',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '$progress/${RewardsState.chestTarget}',
                            key: const Key('chest_progress'),
                            style: styles.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 18,
                            color: AppColors.coinGold,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              'Reward: ${RewardsState.chestReward} Coins',
                              textAlign: TextAlign.center,
                              style: styles.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      if (ready) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Open your chest to start your next reward cycle.',
                          key: const Key('chest_ready_hint'),
                          textAlign: TextAlign.center,
                          style: styles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: _opening ? 'Opening…' : 'Open Chest',
                        leadingIcon: Icon(
                          ready
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                        ),
                        onPressed: ready && !_opening ? _openChest : null,
                      ),
                    ],
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
