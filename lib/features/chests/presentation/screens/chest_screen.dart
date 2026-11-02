import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards_hub/data/rewards_mock_data.dart';
import '../../../rewards_hub/domain/rewards_models.dart';
import '../../../rewards_hub/presentation/providers/rewards_providers.dart';
import '../../../rewards_hub/presentation/widgets/rewards_common_widgets.dart';
import '../widgets/chest_art.dart';

class ChestScreen extends ConsumerStatefulWidget {
  const ChestScreen({super.key});

  @override
  ConsumerState<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends ConsumerState<ChestScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _openController;
  ChestTier? _openingTier;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _openController.dispose();
    super.dispose();
  }

  Future<void> _open(ChestDefinition chest) async {
    if (_openingTier != null) return;
    final state = ref.read(rewardsProvider);
    if (state.chestStatus(chest) != ChestStatus.ready) return;

    setState(() => _openingTier = chest.tier);
    _openController.duration = AppMotion.reduceMotion(context)
        ? const Duration(milliseconds: 300)
        : const Duration(milliseconds: 1500);
    ref.read(gameAudioServiceProvider).play(GameSound.powerUp);
    await _openController.forward(from: 0);
    if (!mounted) return;

    // Credit only after the reveal; the notifier re-checks the status, so a
    // chest can never be claimed twice.
    final rewards = ref.read(rewardsProvider.notifier).openChest(chest.tier);
    if (rewards == null) {
      setState(() => _openingTier = null);
      return;
    }
    ref.read(gameAudioServiceProvider).play(GameSound.coinReward);
    await showRewardPopup(
      context,
      heading: '${chest.name} opened!',
      subtitle: 'Your rewards have been added.',
      rewards: rewards,
    );
    if (!mounted) return;
    setState(() => _openingTier = null);
  }

  void _explain(ChestDefinition chest, RewardsState state) {
    final status = state.chestStatus(chest);
    final remaining = chest.target - state.progressOf(chest.tier);
    final message = switch (status) {
      ChestStatus.locked =>
        '${chest.name} is locked. ${chest.requirement} to start unlocking it.',
      ChestStatus.inProgress =>
        '$remaining more to go: ${chest.requirement.toLowerCase()}.',
      ChestStatus.claimed => 'You have already collected this chest.',
      ChestStatus.ready => '',
    };
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardsProvider);
    final styles = context.appTextStyles;
    final colors = context.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treasure Rewards'),
        actions: const [
          CoinBalanceChip(),
          SizedBox(width: AppSpacing.xs),
          ThemeModeMenu(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Text(
                  'Keep learning to fill each chest, then open it for coins '
                  'and rare items.',
                  style: styles.bodyLarge.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final chest in RewardsMockData.chests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ChestCard(
                      key: ValueKey('chest-${chest.tier.name}'),
                      chest: chest,
                      status: state.chestStatus(chest),
                      progress: state.progressOf(chest.tier),
                      busy: _openingTier != null,
                      openAnimation: _openingTier == chest.tier
                          ? _openController
                          : null,
                      onOpen: () => _open(chest),
                      onExplain: () => _explain(chest, state),
                    ),
                  ),
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

class _ChestCard extends StatelessWidget {
  final ChestDefinition chest;
  final ChestStatus status;
  final int progress;
  final bool busy;
  final Animation<double>? openAnimation;
  final VoidCallback onOpen;
  final VoidCallback onExplain;

  const _ChestCard({
    super.key,
    required this.chest,
    required this.status,
    required this.progress,
    required this.busy,
    required this.openAnimation,
    required this.onOpen,
    required this.onExplain,
  });

  static const Animation<double> _closed = AlwaysStoppedAnimation(0);
  static const Animation<double> _opened = AlwaysStoppedAnimation(1);

  String get _contents {
    final parts = ['${chest.coins} coins'];
    if (chest.bonusPowerUp != null) parts.add('Hint Token');
    final bonusId = chest.bonusShopItemId;
    if (bonusId != null) {
      parts.add(RewardsMockData.productById(bonusId)?.name ?? 'Special item');
    }
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final isReady = status == ChestStatus.ready;
    final isClaimed = status == ChestStatus.claimed;
    final value = (progress / chest.target).clamp(0.0, 1.0);
    final art = openAnimation ?? (isClaimed ? _opened : _closed);

    final (badgeLabel, badgeVariant) = switch (status) {
      ChestStatus.locked => ('Locked', AppBadgeVariant.neutral),
      ChestStatus.inProgress => ('In progress', AppBadgeVariant.primary),
      ChestStatus.ready => ('Ready to open', AppBadgeVariant.success),
      ChestStatus.claimed => ('Claimed', AppBadgeVariant.neutral),
    };

    final buttonLabel = switch (status) {
      ChestStatus.locked => 'Locked',
      ChestStatus.inProgress => '${chest.target - progress} more to go',
      ChestStatus.ready => openAnimation != null ? 'Opening…' : 'Open Chest',
      ChestStatus.claimed => 'Claimed',
    };

    return AppPressable(
      onTap: isReady ? (busy ? null : onOpen) : onExplain,
      borderRadius: AppDimensions.radiusCard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusCard,
          border: Border.all(
            color: isReady ? chest.color : colors.border,
            width: isReady ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    ChestArt(
                      open: art,
                      color: chest.color,
                      colorDark: chest.colorDark,
                      dimmed: status == ChestStatus.locked,
                      size: 88,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chest.name,
                      style: styles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppBadge(label: badgeLabel, variant: badgeVariant),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      chest.description,
                      style: styles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      chest.requirement,
                      style: styles.labelLarge.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: AppProgressBar(
                            value: isClaimed ? 1 : value,
                            accentColor: chest.color,
                            semanticLabel: '${chest.name} progress',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${isClaimed ? chest.target : progress}/${chest.target}',
                          style: styles.badge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Contains: $_contents',
                      style: styles.caption.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: buttonLabel,
                      leadingIcon: isClaimed
                          ? const Icon(Icons.check_rounded)
                          : isReady
                          ? const Icon(Icons.lock_open_rounded)
                          : const Icon(Icons.lock_outline_rounded),
                      onPressed: isReady && !busy ? onOpen : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
