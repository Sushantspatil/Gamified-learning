import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../monetization/presentation/widgets/ad_reward_widgets.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../chest_style.dart';
import '../widgets/chest_hero.dart';
import '../widgets/chest_open_stage.dart';
import '../widgets/chest_progress_track.dart';

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
    final anyReady = state.anyChestReady;

    // The hero is the chest that matters now: the first one ready to open,
    // otherwise the one that is closest to being earned.
    final ready = [
      for (final tier in ChestTier.values)
        if (state.chestReady(tier)) tier,
    ];
    final next = ChestTier.values.reduce(
      (a, b) => state.gamesUntil(b) < state.gamesUntil(a) ? b : a,
    );
    final focus = ready.isNotEmpty ? ready.first : next;
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
                ChestHero(
                  style: ChestStyle.of(focus),
                  ready: ready.isNotEmpty,
                  status: anyReady
                      ? 'A chest is ready. Tap it to open!'
                      : 'Next: ${ChestStyle.of(next).title} in '
                            '$nextGames ${nextGames == 1 ? 'game' : 'games'}',
                  onTap: () => _onTap(focus),
                ),
                const SizedBox(height: AppSpacing.md),
                _TrackCard(state: state),
                const SizedBox(height: AppSpacing.md),
                // A bonus chest for an opt-in rewarded ad (paid by the server
                // after Google confirms the ad); hidden when ads are off.
                const AdChestCard(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your chests',
                  style: styles.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
                  'Chest progress is saved on this device.',
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

/// The games played towards the next chests: "3/10" and the track.
class _TrackCard extends StatelessWidget {
  final RewardsState state;

  const _TrackCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Games played',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${state.chestProgress}/${RewardsState.chestCycle}',
                  key: const Key('chest_progress'),
                  style: styles.titleMedium.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ChestProgressTrack(state: state),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Finish games to earn chests',
              textAlign: TextAlign.center,
              style: styles.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
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
            color: ready
                ? Color.alphaBlend(
                    style.primary.withValues(alpha: 0.16),
                    colors.cardBackground,
                  )
                : colors.cardBackground,
            borderRadius: AppDimensions.radiusCard,
            border: Border.all(
              color: ready ? style.primary : colors.border,
              width: ready ? 2 : 1,
            ),
            // A solid edge underneath: the ready chest looks like it has
            // thickness, and stands out from the locked ones.
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: style.primary.withValues(alpha: 0.75),
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
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
                    ChestArt(style: style, height: artHeight, locked: !ready),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: style.primary,
                        borderRadius: AppDimensions.radiusCircular,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          'Tap to open',
                          textAlign: TextAlign.center,
                          style: styles.caption.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    style.primary.withValues(alpha: 0.35),
                    style.primary.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Image.asset(
                  style.frameAsset(ChestFrame.closed),
                  height: 84,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox(height: 84),
                ),
              ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: style.primary,
                  foregroundColor: Colors.black,
                  textStyle: styles.labelLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
