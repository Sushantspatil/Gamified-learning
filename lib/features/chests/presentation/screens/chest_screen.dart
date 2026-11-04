import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../chest_style.dart';
import '../widgets/chest_open_view.dart';

class ChestScreen extends ConsumerStatefulWidget {
  const ChestScreen({super.key});

  @override
  ConsumerState<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends ConsumerState<ChestScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _openDuration = Duration(milliseconds: 2600);

  /// One controller drives whichever chest was tapped; the other two stay
  /// still on their closed frame.
  late final AnimationController _open;
  ChestStyle? _selected;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Decode every frame now so nothing pops in while a chest is opening.
    for (final style in ChestStyle.values) {
      for (final frame in ChestFrame.values) {
        precacheImage(
          AssetImage(style.frameAsset(frame)),
          context,
          onError: (_, _) {},
        );
      }
    }
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  Future<void> _onTap(ChestStyle style) async {
    // One chest at a time; further taps while it opens do nothing.
    if (_selected != null) return;

    if (!ref.read(rewardsProvider).chestReady) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Complete 3 games to unlock your chest.'),
          ),
        );
      return;
    }

    setState(() => _selected = style);
    final reduce = AppMotion.reduceMotion(context);
    _open.duration = reduce ? const Duration(milliseconds: 300) : _openDuration;
    await _open.forward(from: 0);
    if (!mounted) return; // nothing was paid; the chest stays ready

    // The reward is claimed once, here, by the existing rewards logic, and
    // only after the animation has finished. It does not depend on which of
    // the three chests was chosen: every chest pays the same chest reward.
    final opened = ref.read(rewardsProvider.notifier).openChest();
    if (opened) {
      // The chest stays open behind the reward dialog.
      await showRewardDialog(
        context,
        title: 'Chest opened!',
        message: 'You received ${RewardsState.chestReward} Coins.',
        icon: Icons.inventory_2_rounded,
      );
    }
    if (!mounted) return;
    _open.value = 0;
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final progress = ref.watch(rewardsProvider.select((s) => s.chestProgress));
    final ready = progress >= RewardsState.chestTarget;
    final reduce = AppMotion.reduceMotion(context);

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
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: AppSpacing.paddingMd,
              children: [
                AppCard(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    children: [
                      Text('Treasure Chest', style: styles.headingMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        ready
                            ? 'Your chest is ready!'
                            : 'Complete 3 games to unlock your chest.',
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
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  ready ? 'Tap a chest to open it' : 'Your chests',
                  style: styles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 520;
                    final tiles = [
                      for (final style in ChestStyle.values)
                        _ChestTile(
                          key: Key('chest-${style.name}'),
                          style: style,
                          height: wide
                              ? math.min(
                                  150.0,
                                  (constraints.maxWidth / 3 - 40) /
                                      style.aspectRatio,
                                )
                              : 150,
                          progress: _selected == style
                              ? _open
                              : const AlwaysStoppedAnimation<double>(0),
                          ready: ready,
                          busy: _selected != null,
                          reduceMotion: reduce,
                          onTap: () => _onTap(style),
                        ),
                    ];
                    if (!wide) {
                      return Column(
                        children: [
                          for (final tile in tiles)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: tile,
                            ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(child: tiles[i]),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Demo mode: progress and rewards live on this device only.',
                  textAlign: TextAlign.center,
                  style: styles.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable chest. Only the tapped chest animates; the others keep their
/// closed frame.
class _ChestTile extends StatelessWidget {
  final ChestStyle style;
  final double height;
  final Animation<double> progress;
  final bool ready;
  final bool busy;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _ChestTile({
    super.key,
    required this.style,
    required this.height,
    required this.progress,
    required this.ready,
    required this.busy,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final active = ready && !busy;

    return Semantics(
      button: true,
      enabled: active,
      label: ready ? 'Open ${style.title}' : '${style.title}, locked',
      child: AppPressable(
        onTap: onTap,
        borderRadius: AppDimensions.radiusCard,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: AppDimensions.radiusCard,
            border: Border.all(
              color: ready ? style.primary : colors.border,
              width: ready ? 1.5 : 1,
            ),
          ),
          // Light from the chest is clipped to its own card.
          child: ClipRRect(
            borderRadius: AppDimensions.radiusCard,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: ready ? 1 : 0.6,
                    child: ChestOpenView(
                      style: style,
                      progress: progress,
                      height: height,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    style.title,
                    style: styles.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready ? 'Tap to open' : 'Locked',
                    style: styles.caption.copyWith(
                      color: ready ? style.primary : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
