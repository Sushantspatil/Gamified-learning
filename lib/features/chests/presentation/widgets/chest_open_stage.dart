import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/coin_flight.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../../../rewards/presentation/widgets/live_balance_chip.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/equipped_cosmetics.dart';
import '../chest_style.dart';
import 'chest_open_view.dart';
import 'chest_rive_view.dart';

/// Shows the large, centred "opening" view for [tier]: the chest plays its
/// full animation on a dark stage, then the reward appears under it.
///
/// [forced] opens a chest that was not earned and charges its coin price;
/// otherwise an earned chest is used. Either way the reward is claimed once,
/// by the rewards controller, only after the animation has finished: leaving
/// before then costs and pays nothing.
Future<void> showChestOpenStage(
  BuildContext context, {
  required ChestTier tier,
  required bool forced,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Chest opening',
    barrierColor: Colors.black.withValues(alpha: 0.96),
    transitionDuration: AppMotion.duration(context, AppMotion.slow),
    pageBuilder: (context, _, _) => ChestOpenStage(tier: tier, forced: forced),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class ChestOpenStage extends ConsumerStatefulWidget {
  final ChestTier tier;
  final bool forced;

  const ChestOpenStage({super.key, required this.tier, required this.forced});

  @override
  ConsumerState<ChestOpenStage> createState() => _ChestOpenStageState();
}

class _ChestOpenStageState extends ConsumerState<ChestOpenStage>
    with SingleTickerProviderStateMixin {
  static const Duration _openDuration = Duration(milliseconds: 3600);

  late final AnimationController _open = AnimationController(vsync: this);
  ChestOpenResult? _result;
  bool _started = false;

  // The two ends of the coins' flight: the reward and the balance in the corner.
  final GlobalKey _rewardKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();
  OverlayEntry? _flight;

  ChestStyle get _style => ChestStyle.of(widget.tier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = AppMotion.reduceMotion(context);
    _open.duration = reduce ? const Duration(milliseconds: 300) : _openDuration;
    _run(reduce);
  }

  Future<void> _run(bool reduce) async {
    // Give the Rive animation (preloaded by the chest screen) a moment, so
    // the opening does not start on the picture film while it loads.
    if (!reduce) await chestRiveReady(_style);
    if (!mounted) return;
    await _open.forward(from: 0);
    if (!mounted) return; // closed early: nothing was charged or paid
    final rewards = ref.read(rewardsProvider.notifier);
    final result = widget.forced
        ? rewards.forceOpenChest(widget.tier)
        : rewards.openChest(widget.tier);
    setState(() => _result = result);
    // Once the reward is on screen, its coins fly to the balance.
    WidgetsBinding.instance.addPostFrameCallback((_) => _flyReward(result));
  }

  void _flyReward(ChestOpenResult result) {
    final coins = result.reward?.coins ?? 0;
    if (!mounted || coins <= 0) return;
    _flight = flyCoins(
      context,
      from: _rewardKey,
      to: _balanceKey,
      count: (coins ~/ 6).clamp(6, 14),
    );
  }

  @override
  void dispose() {
    _open.dispose();
    final flight = _flight;
    if (flight != null && flight.mounted) flight.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final result = _result;
    final done = result != null;

    return PopScope(
      canPop: done,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // As large as the screen allows, but not taller than 260: the
                  // artwork is only ~250 pixels, so drawing it larger than that
                  // on a phone only makes it soft.
                  final height = math.min(
                    260.0,
                    math.min(
                      constraints.maxHeight * 0.36,
                      constraints.maxWidth * 0.78 / style.aspectRatio,
                    ),
                  );
                  return Center(
                    child: SingleChildScrollView(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            style.title,
                            key: const Key('chest_stage_title'),
                            textAlign: TextAlign.center,
                            style: AppTypography.headingMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.10),
                          // The Rive animation when this chest has one,
                          // else the picture film.
                          ChestRiveView(
                            style: style,
                            progress: _open,
                            height: height,
                            reduceMotion: AppMotion.reduceMotion(context),
                            fallback: ChestOpenView(
                              key: const Key('chest_stage_chest'),
                              style: style,
                              progress: _open,
                              height: height,
                              reduceMotion: AppMotion.reduceMotion(context),
                            ),
                          ),
                          SizedBox(height: height * 0.10),
                          AnimatedSwitcher(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.slow,
                            ),
                            child: done
                                ? _ResultPanel(
                                    key: const ValueKey('result'),
                                    style: style,
                                    result: result,
                                    rewardKey: _rewardKey,
                                  )
                                : Text(
                                    'Opening…',
                                    key: const ValueKey('opening'),
                                    style: AppTypography.body.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
              right: AppSpacing.md,
              child: Theme(
                data: AppTheme.darkTheme,
                child: KeyedSubtree(
                  key: _balanceKey,
                  child: const LiveBalanceChip(),
                ),
              ),
            ),
            // The character joins in when the chest has paid out.
            if (result != null && result.opened)
              Positioned(
                left: 8,
                bottom: MediaQuery.paddingOf(context).bottom + 8,
                child: Character3dView(
                  width: 96,
                  height: 128,
                  state: Character3dState.idle,
                  initialAction: Character3dAction.cheer,
                  cosmetics: equippedCosmetics(context),
                  placeholder: const SizedBox.shrink(),
                  fallback: const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final ChestStyle style;
  final ChestOpenResult result;

  /// Marks the reward, where the coins fly from.
  final GlobalKey rewardKey;

  const _ResultPanel({
    super.key,
    required this.style,
    required this.result,
    required this.rewardKey,
  });

  @override
  Widget build(BuildContext context) {
    final reward = result.reward;
    final Widget icon;
    final Widget title;
    final String subtitle;
    final Color tint;

    const titleStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: 26,
    );

    if (reward == null) {
      tint = Colors.white54;
      icon = const Icon(
        Icons.info_outline_rounded,
        size: 48,
        color: Colors.white70,
      );
      title = Text(
        switch (result.status) {
          ChestOpenStatus.notEnoughCoins => 'Not enough coins',
          _ => 'This chest is not ready',
        },
        key: const Key('chest_reward_title'),
        textAlign: TextAlign.center,
        style: titleStyle,
      );
      subtitle = 'Nothing was spent.';
    } else if (reward.cosmetic != null) {
      final item = reward.cosmetic!;
      tint = item.color;
      icon = CircleAvatar(
        radius: 28,
        backgroundColor: item.color.withValues(alpha: 0.25),
        child: Icon(item.icon, size: 30, color: item.color),
      );
      title = Text(
        '${item.name} unlocked!',
        key: const Key('chest_reward_title'),
        textAlign: TextAlign.center,
        style: titleStyle,
      );
      subtitle =
          'Added to your ${item.kind == ProductKind.avatar ? 'avatars' : 'frames'}. '
          'Equip it in the Shop.';
    } else if (reward.gems > 0) {
      tint = GemBalanceChip.gemColor;
      icon = const Icon(
        Icons.diamond_rounded,
        size: 52,
        color: GemBalanceChip.gemColor,
      );
      title = AnimatedCountText(
        key: const Key('chest_reward_title'),
        value: reward.gems,
        prefix: '+',
        suffix: ' Gems',
        textAlign: TextAlign.center,
        duration: const Duration(milliseconds: 900),
        style: titleStyle,
      );
      subtitle = 'Added to your gems.';
    } else {
      tint = AppColors.coinGold;
      icon = const Icon(
        Icons.monetization_on_rounded,
        size: 52,
        color: AppColors.coinGold,
      );
      title = AnimatedCountText(
        key: const Key('chest_reward_title'),
        value: reward.coins,
        prefix: '+',
        suffix: ' Coins',
        textAlign: TextAlign.center,
        duration: const Duration(milliseconds: 900),
        style: titleStyle,
      );
      subtitle = reward.tier == ChestTier.cyber
          ? 'You already own every cosmetic, so you got coins instead.'
          : 'Added to your balance.';
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppDimensions.radiusCard,
        color: Color.alphaBlend(
          tint.withValues(alpha: 0.16),
          const Color(0xFF12141F),
        ),
        border: Border.all(color: tint, width: 2),
        // A solid edge underneath, like the tiles on the result screen.
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.75),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(key: rewardKey, child: icon),
            const SizedBox(height: AppSpacing.xs),
            title,
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              key: const Key('chest_reward_subtitle'),
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The card pops in.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.85, end: 1),
          duration: AppMotion.duration(context, AppMotion.slow),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: card,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('chest_collect'),
          style: FilledButton.styleFrom(
            backgroundColor: style.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md - 2,
            ),
            textStyle: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(result.opened ? 'Collect' : 'Close'),
        ),
      ],
    );
  }
}
