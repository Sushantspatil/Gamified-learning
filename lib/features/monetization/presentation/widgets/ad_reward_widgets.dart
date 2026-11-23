import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/monetization_models.dart';
import '../providers/monetization_providers.dart';

/// Runs a rewarded ad the player asked for and tells them what happened.
/// Ads only ever start from a tap like this: never on their own and never
/// during a game.
Future<void> runAdReward(
  BuildContext context,
  WidgetRef ref,
  String placement,
) async {
  final result = await ref.read(adRewardRunnerProvider).run(placement);
  if (!context.mounted) return;
  if (result.status == AdRunStatus.rewarded) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.card_giftcard_rounded, size: 40),
        title: Text(
          placement == AdPlacements.adChest ? 'Chest opened!' : 'Reward added',
        ),
        content: Text(result.message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nice!'),
          ),
        ],
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(result.message)));
}

class _RewardInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  const _RewardInfo(this.title, this.subtitle, this.icon);
}

const _rewardInfo = <String, _RewardInfo>{
  AdPlacements.adChest: _RewardInfo(
    'Ad chest',
    'Coins, sometimes a 50:50 or gems',
    Icons.inventory_2_rounded,
  ),
  AdPlacements.fiftyFifty: _RewardInfo(
    '50:50 token',
    'Hide two wrong answers in a quiz',
    Icons.filter_2_rounded,
  ),
  AdPlacements.addTime: _RewardInfo(
    '+5 seconds token',
    'More time in Sudden Death',
    Icons.timer_outlined,
  ),
  AdPlacements.skip: _RewardInfo(
    'Skip token',
    'Skip one Sudden Death question',
    Icons.fast_forward_rounded,
  ),
};

/// One reward row: what you get, how many are left today, and a button.
class AdRewardTile extends ConsumerStatefulWidget {
  final String placement;
  final AdsConfig config;
  final int tokensHeld;

  const AdRewardTile({
    super.key,
    required this.placement,
    required this.config,
    this.tokensHeld = 0,
  });

  @override
  ConsumerState<AdRewardTile> createState() => _AdRewardTileState();
}

class _AdRewardTileState extends ConsumerState<AdRewardTile> {
  bool _busy = false;

  Future<void> _go() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await runAdReward(context, ref, widget.placement);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final info = _rewardInfo[widget.placement]!;
    final p = widget.config.placement(widget.placement);
    final available = p?.available ?? false;
    final note = switch (p?.reason) {
      'daily_limit' => 'Come back tomorrow',
      'token_limit' => 'You hold the most allowed',
      'ads_unavailable' => 'Not available right now',
      _ => '${p?.remainingToday ?? 0} left today',
    };
    final label = widget.config.adFree ? 'Claim' : 'Watch ad';
    return ListTile(
      key: Key('ad_reward_${widget.placement}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(info.icon, color: colors.primary),
      title: Text(info.title, style: styles.labelLarge),
      subtitle: Text(
        [
          info.subtitle,
          if (widget.tokensHeld > 0) 'You have ${widget.tokensHeld}',
          note,
        ].join(' · '),
        style: styles.bodySmall.copyWith(color: colors.textSecondary),
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: available && !_busy ? _go : null,
        icon: _busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                widget.config.adFree
                    ? Icons.redeem_rounded
                    : Icons.play_circle_outline_rounded,
                size: 18,
              ),
        label: Text(label),
      ),
    );
  }
}

/// Free rewards for watching a short rewarded ad (or free with the Quiz Pass).
class FreeRewardsCard extends ConsumerWidget {
  const FreeRewardsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(adsConfigProvider).valueOrNull;
    final tokens =
        ref.watch(powerUpsStatusProvider).valueOrNull ?? PowerUpsStatus.empty;
    if (config == null || (!config.rewardedAdsEnabled && !config.adFree)) {
      return const SizedBox.shrink();
    }
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    return AppCard(
      key: const Key('free_rewards_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Free rewards', style: styles.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            config.adFree
                ? 'Quiz Pass: claim these without watching ads.'
                : 'Watch a short video to get a reward. Ads never interrupt a game.',
            style: styles.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Only what the server offers (it decides placements and caps).
          for (final id in const [
            AdPlacements.adChest,
            AdPlacements.fiftyFifty,
            AdPlacements.addTime,
            AdPlacements.skip,
          ])
            if (config.placement(id) != null)
              AdRewardTile(
                placement: id,
                config: config,
                tokensHeld: tokens.tokens(id),
              ),
        ],
      ),
    );
  }
}

/// The ad chest on the Chest Box screen.
class AdChestCard extends ConsumerWidget {
  const AdChestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(adsConfigProvider).valueOrNull;
    if (config == null || (!config.rewardedAdsEnabled && !config.adFree)) {
      return const SizedBox.shrink();
    }
    final styles = context.appTextStyles;
    return AppCard(
      key: const Key('ad_chest_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Free ad chest', style: styles.titleLarge),
          AdRewardTile(placement: AdPlacements.adChest, config: config),
        ],
      ),
    );
  }
}
