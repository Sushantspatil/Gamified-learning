import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/equipped_cosmetics.dart';
import '../chest_style.dart';
import 'chest_open_view.dart';

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
    barrierColor: Colors.black.withValues(alpha: 0.9),
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
  static const Duration _openDuration = Duration(milliseconds: 2600);

  late final AnimationController _open = AnimationController(vsync: this);
  ChestOpenResult? _result;
  bool _started = false;

  ChestStyle get _style => ChestStyle.of(widget.tier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = AppMotion.reduceMotion(context);
    _open.duration = reduce ? const Duration(milliseconds: 300) : _openDuration;
    _run();
  }

  Future<void> _run() async {
    await _open.forward(from: 0);
    if (!mounted) return; // closed early: nothing was charged or paid
    final rewards = ref.read(rewardsProvider.notifier);
    final result = widget.forced
        ? rewards.forceOpenChest(widget.tier)
        : rewards.openChest(widget.tier);
    setState(() => _result = result);
  }

  @override
  void dispose() {
    _open.dispose();
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
                  // As large as the screen allows, but never taller than ~300.
                  final height = math.min(
                    300.0,
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
                          SizedBox(height: height * 0.18),
                          ChestOpenView(
                            key: const Key('chest_stage_chest'),
                            style: style,
                            progress: _open,
                            height: height,
                            reduceMotion: AppMotion.reduceMotion(context),
                          ),
                          SizedBox(height: height * 0.18),
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

  const _ResultPanel({super.key, required this.style, required this.result});

  @override
  Widget build(BuildContext context) {
    final reward = result.reward;
    final Widget icon;
    final String title;
    final String subtitle;

    if (reward == null) {
      icon = const Icon(
        Icons.info_outline_rounded,
        size: 44,
        color: Colors.white70,
      );
      title = switch (result.status) {
        ChestOpenStatus.notEnoughCoins => 'Not enough coins',
        _ => 'This chest is not ready',
      };
      subtitle = 'Nothing was spent.';
    } else if (reward.cosmetic != null) {
      final item = reward.cosmetic!;
      icon = CircleAvatar(
        radius: 30,
        backgroundColor: item.color.withValues(alpha: 0.25),
        child: Icon(item.icon, size: 32, color: item.color),
      );
      title = '${item.name} unlocked!';
      subtitle =
          'Added to your ${item.kind == ProductKind.avatar ? 'avatars' : 'frames'}. '
          'Equip it in the Shop.';
    } else if (reward.gems > 0) {
      icon = const Icon(
        Icons.diamond_rounded,
        size: 48,
        color: GemBalanceChip.gemColor,
      );
      title = '+${reward.gems} Gems';
      subtitle = 'Added to your gems.';
    } else {
      icon = const Icon(
        Icons.monetization_on_rounded,
        size: 48,
        color: AppColors.coinGold,
      );
      title = '+${reward.coins} Coins';
      subtitle = reward.tier == ChestTier.cyber
          ? 'You already own every cosmetic, so you got coins instead.'
          : 'Added to your balance.';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          key: const Key('chest_reward_title'),
          textAlign: TextAlign.center,
          style: AppTypography.headingMedium.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          key: const Key('chest_reward_subtitle'),
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: Colors.white70),
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
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(result.opened ? 'Collect' : 'Close'),
        ),
      ],
    );
  }
}
