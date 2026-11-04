import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../widgets/chest_open_stage.dart';

class ChestScreen extends ConsumerStatefulWidget {
  const ChestScreen({super.key});

  @override
  ConsumerState<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends ConsumerState<ChestScreen> {
  bool _precached = false;

  /// One chest at a time: set synchronously on tap, so rapid taps do nothing.
  bool _busy = false;

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

  Future<void> _onTap(ChestTier tier) async {
    if (_busy) return;
    _busy = true;
    try {
      if (ref.read(rewardsProvider).chestReady(tier)) {
        await showChestOpenStage(context, tier: tier, forced: false);
        return;
      }
      final openNow = await _showLockedSheet(tier);
      if (openNow == true && mounted) {
        await showChestOpenStage(context, tier: tier, forced: true);
      }
    } finally {
      _busy = false;
    }
  }

  Future<bool?> _showLockedSheet(ChestTier tier) {
    final state = ref.read(rewardsProvider);
    final style = ChestStyle.of(tier);
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.themeColors.surface,
      builder: (context) => _LockedSheet(
        style: style,
        gamesLeft: state.gamesUntil(tier),
        coins: state.coins,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final state = ref.watch(rewardsProvider);
    final progress = state.chestProgress;
    final anyReady = state.anyChestReady;

    final next = ChestTier.values.reduce(
      (a, b) => state.gamesUntil(b) < state.gamesUntil(a) ? b : a,
    );
    final nextGames = state.gamesUntil(next);

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
                      Text('Treasure Chests', style: styles.headingMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        anyReady
                            ? 'A chest is ready. Tap it to open!'
                            : 'Next: ${ChestStyle.of(next).title} in '
                                  '$nextGames ${nextGames == 1 ? 'game' : 'games'}',
                        key: const Key('chest_status'),
                        textAlign: TextAlign.center,
                        style: styles.bodyLarge.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(child: _CycleProgress(state: state)),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '$progress/${RewardsState.chestCycle}',
                            key: const Key('chest_progress'),
                            style: styles.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Finish games to earn chests',
                        style: styles.caption.copyWith(color: colors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const GemBalanceChip(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Your chests', style: styles.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = AppSpacing.sm;
                    final tileWidth =
                        (constraints.maxWidth - gap * 2) /
                        ChestTier.values.length;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final tier in ChestTier.values) ...[
                            if (tier != ChestTier.values.first)
                              const SizedBox(width: gap),
                            Expanded(
                              child: _ChestTile(
                                key: Key('chest-${tier.name}'),
                                style: ChestStyle.of(tier),
                                tier: tier,
                                state: state,
                                artHeight: math.min(
                                  96,
                                  (tileWidth - 16) /
                                      ChestStyle.of(tier).aspectRatio,
                                ),
                                onTap: () => _onTap(tier),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Tap a locked chest to open it now with coins.',
                  textAlign: TextAlign.center,
                  style: styles.caption.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
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

/// The 10-game cycle: one bar with a marker where each chest is earned.
class _CycleProgress extends StatelessWidget {
  final RewardsState state;

  const _CycleProgress({required this.state});

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const dot = 14.0;
        double centerOf(ChestTier tier) =>
            (width * tier.unlockAt / RewardsState.chestCycle).clamp(
              dot / 2,
              width - dot / 2,
            );
        return SizedBox(
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: AppProgressBar(
                  value: state.chestProgress / RewardsState.chestCycle,
                  semanticLabel: 'Chest progress',
                ),
              ),
              for (final tier in ChestTier.values) ...[
                Positioned(
                  left: centerOf(tier) - dot / 2,
                  top: 12 - dot / 2,
                  child: _Marker(
                    color: ChestStyle.of(tier).primary,
                    filled:
                        state.chestProgress >= tier.unlockAt ||
                        state.chestReady(tier),
                    size: dot,
                  ),
                ),
                Positioned(
                  left: centerOf(tier) - 14,
                  width: 28,
                  top: 24,
                  child: Text(
                    '${tier.unlockAt}',
                    textAlign: TextAlign.center,
                    style: styles.caption.copyWith(color: colors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Marker extends StatelessWidget {
  final Color color;
  final bool filled;
  final double size;

  const _Marker({
    required this.color,
    required this.filled,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : context.themeColors.surface,
        border: Border.all(color: color, width: 2),
      ),
      child: SizedBox(width: size, height: size),
    );
  }
}

/// One chest in the row: its closed artwork and either "Tap to open" (earned)
/// or the games left plus its coin price (locked).
class _ChestTile extends StatelessWidget {
  final ChestStyle style;
  final ChestTier tier;
  final RewardsState state;
  final double artHeight;
  final VoidCallback onTap;

  const _ChestTile({
    super.key,
    required this.style,
    required this.tier,
    required this.state,
    required this.artHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final count = state.chestsReadyCount(tier);
    final ready = count > 0;
    final gamesLeft = state.gamesUntil(tier);
    final canAfford = state.coins >= tier.forcePrice;

    return Semantics(
      button: true,
      label: ready
          ? 'Open ${style.title}'
          : '${style.title}, $gamesLeft more games, or ${tier.forcePrice} coins',
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: ready ? 1 : 0.55,
                      child: Image.asset(
                        style.frameAsset(ChestFrame.closed),
                        height: artHeight,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => SizedBox(height: artHeight),
                      ),
                    ),
                    if (!ready)
                      Positioned(
                        right: 0,
                        top: -AppSpacing.xs,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: colors.textMuted,
                        ),
                      ),
                    if (count > 1)
                      Positioned(
                        right: 0,
                        top: -AppSpacing.xs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: style.primary,
                            borderRadius: AppDimensions.radiusCircular,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'x$count',
                              key: Key('chest-count-${tier.name}'),
                              style: styles.caption.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(style.title, style: styles.labelLarge),
                ),
                const SizedBox(height: 2),
                Text(
                  style.prize,
                  style: styles.caption.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (ready)
                  Text(
                    'Tap to open',
                    textAlign: TextAlign.center,
                    style: styles.caption.copyWith(
                      color: style.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else ...[
                  Text(
                    '$gamesLeft more ${gamesLeft == 1 ? 'game' : 'games'}',
                    textAlign: TextAlign.center,
                    style: styles.caption.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _PricePill(
                      price: tier.forcePrice,
                      affordable: canAfford,
                      color: style.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final int price;
  final bool affordable;
  final Color color;

  const _PricePill({
    required this.price,
    required this.affordable,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppDimensions.radiusCircular,
        border: Border.all(color: affordable ? color : colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              size: 14,
              color: AppColors.coinGold,
            ),
            const SizedBox(width: 4),
            Text(
              '$price',
              style: styles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: affordable ? colors.textPrimary : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a locked chest is tapped: wait for the games, or pay to open.
class _LockedSheet extends StatelessWidget {
  final ChestStyle style;
  final int gamesLeft;
  final int coins;

  const _LockedSheet({
    required this.style,
    required this.gamesLeft,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final price = style.tier.forcePrice;
    final canAfford = coins >= price;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              style.frameAsset(ChestFrame.closed),
              height: 84,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox(height: 84),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(style.title, style: styles.headingSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Finish $gamesLeft more ${gamesLeft == 1 ? 'game' : 'games'} to '
              'earn it for free, or open it now with coins.',
              key: const Key('chest_locked_text'),
              textAlign: TextAlign.center,
              style: styles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('chest_force_open'),
                onPressed: canAfford
                    ? () => Navigator.of(context).pop(true)
                    : null,
                icon: const Icon(Icons.monetization_on_rounded, size: 20),
                label: Text('Open now for $price coins'),
              ),
            ),
            if (!canAfford) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You need ${price - coins} more coins.',
                key: const Key('chest_need_coins'),
                style: styles.caption.copyWith(color: colors.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep playing'),
            ),
          ],
        ),
      ),
    );
  }
}
