import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/character_glow.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/data/rewards_catalog.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';

enum _ShopTab {
  avatars('Avatars', Icons.face_retouching_natural_rounded),
  frames('Profile Frames', Icons.account_circle_outlined),
  powerUps('Power-ups', Icons.bolt_rounded);

  final String label;
  final IconData icon;
  const _ShopTab(this.label, this.icon);
}

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  _ShopTab _tab = _ShopTab.avatars;

  /// True while a purchase sheet is open, so taps cannot stack purchases.
  bool _busy = false;

  /// What the character is trying on. Null means "what you have equipped".
  String? _previewAvatarId;
  String? _previewFrameId;
  ShopProduct? _lastPreview;

  final Character3dController _character = Character3dController();

  List<ShopProduct> get _products => switch (_tab) {
    _ShopTab.avatars => RewardsCatalog.avatars,
    _ShopTab.frames => RewardsCatalog.frames,
    _ShopTab.powerUps => RewardsCatalog.powerUps,
  };

  @override
  void dispose() {
    _character.dispose();
    super.dispose();
  }

  /// Puts an avatar or frame on the character, so you see it before buying.
  void _preview(ShopProduct product) {
    if (product.kind == ProductKind.powerUp || product.comingSoon) return;
    setState(() {
      if (product.kind == ProductKind.avatar) _previewAvatarId = product.id;
      if (product.kind == ProductKind.frame) _previewFrameId = product.id;
      _lastPreview = product;
    });
    _character.sparkle();
  }

  Future<void> _buy(ShopProduct product) async {
    if (_busy) return;
    _busy = true;
    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        // The default sheet is capped at about half the screen, which would
        // cut the buttons off on a short phone.
        isScrollControlled: true,
        backgroundColor: context.themeColors.surface,
        builder: (context) => _ConfirmSheet(
          product: product,
          coins: ref.read(rewardsProvider).coins,
        ),
      );
      if (confirmed != true || !mounted) return;

      final outcome = ref.read(rewardsProvider.notifier).purchase(product.id);
      final message = switch (outcome) {
        PurchaseOutcome.success =>
          'Purchase successful! ${product.name} is now yours.',
        PurchaseOutcome.notEnoughCoins =>
          'Not enough coins. Earn more coins to purchase this item.',
        PurchaseOutcome.alreadyOwned => 'You already own ${product.name}.',
        PurchaseOutcome.unavailable => '${product.name} is not available yet.',
      };
      final bought = outcome == PurchaseOutcome.success;
      final wearable = product.kind != ProductKind.powerUp;
      if (bought && wearable) {
        _preview(product);
        _character.play(Character3dAction.cheer);
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: bought && wearable
                ? SnackBarAction(
                    label: 'Wear it now',
                    onPressed: () =>
                        ref.read(rewardsProvider.notifier).equip(product.id),
                  )
                : null,
          ),
        );
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final state = ref.watch(rewardsProvider);
    final products = _products;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final showStage = _tab != _ShopTab.powerUps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
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
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showStage) ...[
                          _PreviewStage(
                            controller: _character,
                            avatarId: _previewAvatarId ?? state.equippedAvatar,
                            frameId: _previewFrameId ?? state.equippedFrame,
                            previewing: _lastPreview,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final tab in _ShopTab.values)
                              ChoiceChip(
                                avatar: Icon(
                                  tab.icon,
                                  size: 18,
                                  color: _tab == tab
                                      ? colors.primaryForeground
                                      : colors.textSecondary,
                                ),
                                label: Text(tab.label),
                                selected: _tab == tab,
                                showCheckmark: false,
                                selectedColor: colors.primary,
                                side: BorderSide(color: colors.border),
                                labelStyle: styles.badge.copyWith(
                                  color: _tab == tab
                                      ? colors.primaryForeground
                                      : colors.textPrimary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDimensions.radiusCircular,
                                ),
                                onSelected: (_) => setState(() => _tab = tab),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.ms,
                      crossAxisSpacing: AppSpacing.ms,
                      mainAxisExtent: 212 * scale,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = products[index];
                      return _ProductCard(
                        key: ValueKey(product.id),
                        product: product,
                        state: state,
                        selected:
                            product.id == _previewAvatarId ||
                            product.id == _previewFrameId,
                        onSelect: () => _preview(product),
                        onBuy: () => _buy(product),
                        onEquip: () => ref
                            .read(rewardsProvider.notifier)
                            .equip(product.id),
                      );
                    }, childCount: products.length),
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

/// The character wearing what you are looking at, so you see it before you
/// buy. Without 3D, a large badge of the same item takes its place.
class _PreviewStage extends StatelessWidget {
  final Character3dController controller;
  final String? avatarId;
  final String? frameId;
  final ShopProduct? previewing;

  const _PreviewStage({
    required this.controller,
    required this.avatarId,
    required this.frameId,
    required this.previewing,
  });

  static ShopProduct? _find(String? id) {
    if (id == null) return null;
    for (final product in RewardsCatalog.all) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final shown = _find(avatarId) ?? _find(frameId);
    final accent = (previewing ?? shown)?.color ?? colors.primary;

    return DecoratedBox(
      key: const Key('shop_preview'),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.16),
            colors.cardBackground.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            SizedBox(
              height: 168,
              child: CharacterGlow(
                color: accent,
                child: Character3dView(
                  width: 140,
                  height: 168,
                  state: Character3dState.idle,
                  controller: controller,
                  cosmetics: Character3dCosmetics.fromShopIds(
                    avatarId: avatarId,
                    frameId: frameId,
                  ),
                  ambient: true,
                  initialAction: Character3dAction.wave,
                  placeholder: const SizedBox.shrink(),
                  arrive: true,
                  fallback: _ItemArt(
                    product:
                        _find(avatarId) ??
                        _find(frameId) ??
                        RewardsCatalog.avatars.first,
                    size: 96,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              previewing == null
                  ? 'Your look'
                  : 'Previewing: ${previewing!.name}',
              style: styles.labelLarge.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// One item: a big picture, its state, its price and one clear button.
class _ProductCard extends StatelessWidget {
  final ShopProduct product;
  final RewardsState state;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _ProductCard({
    super.key,
    required this.product,
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onBuy,
    required this.onEquip,
  });

  bool get _owned => switch (product.kind) {
    ProductKind.avatar => state.ownedAvatars.contains(product.id),
    ProductKind.frame => state.ownedFrames.contains(product.id),
    ProductKind.powerUp => false,
  };

  bool get _equipped =>
      state.equippedAvatar == product.id || state.equippedFrame == product.id;

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final isPowerUp = product.kind == ProductKind.powerUp;
    final quantity = isPowerUp ? state.powerUpCount(product.powerUp!) : 0;
    final missing = product.price - state.coins;

    // One button, always saying what happens (or why it cannot).
    final Widget action;
    if (product.comingSoon) {
      action = const _CardButton(label: 'Coming soon');
    } else if (_owned) {
      action = _CardButton(
        label: _equipped ? 'Equipped' : 'Equip',
        onPressed: _equipped ? null : onEquip,
      );
    } else if (missing > 0) {
      action = _CardButton(label: 'Need $missing more');
    } else {
      action = _CardButton(label: 'Buy', onPressed: onBuy);
    }

    final Widget? badge;
    if (_equipped) {
      badge = const _StateBadge(label: 'Equipped', positive: true);
    } else if (_owned) {
      badge = const _StateBadge(label: 'Owned', positive: true);
    } else if (isPowerUp && !product.comingSoon) {
      badge = _StateBadge(label: '×$quantity', positive: quantity > 0);
    } else {
      badge = null;
    }

    return AppPressable(
      onTap: onSelect,
      borderRadius: AppDimensions.radiusCard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusCard,
          border: Border.all(
            color: _equipped
                ? colors.success
                : selected
                ? colors.primary
                : colors.border,
            width: _equipped || selected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.ms),
          child: Opacity(
            opacity: product.comingSoon ? 0.6 : 1,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _ItemArt(product: product, size: 78),
                    if (badge != null)
                      Positioned(top: -2, right: -2, child: badge),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.labelLarge,
                ),
                const SizedBox(height: 2),
                if (_owned || product.comingSoon)
                  const SizedBox(height: 18)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 16,
                        color: AppColors.coinGold,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${product.price} Coins',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final String label;
  final bool positive;

  const _StateBadge({required this.label, required this.positive});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final color = positive ? colors.success : colors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppDimensions.radiusCircular,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          style: context.appTextStyles.badge.copyWith(color: color),
        ),
      ),
    );
  }
}

/// The picture of an item: an avatar badge, a frame ring or a token.
class _ItemArt extends StatelessWidget {
  final ShopProduct product;
  final double size;

  const _ItemArt({required this.product, required this.size});

  @override
  Widget build(BuildContext context) {
    final colour = product.color;
    final isFrame = product.kind == ProductKind.frame;
    final isToken = product.kind == ProductKind.powerUp;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isToken ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isToken ? BorderRadius.circular(size * 0.28) : null,
        gradient: RadialGradient(
          colors: [
            colour.withValues(alpha: isFrame ? 0.06 : 0.34),
            colour.withValues(alpha: isFrame ? 0.02 : 0.10),
          ],
        ),
        border: Border.all(color: colour, width: isFrame ? size * 0.075 : 2),
        boxShadow: [
          BoxShadow(
            color: colour.withValues(alpha: 0.30),
            blurRadius: size * 0.22,
          ),
        ],
      ),
      child: Icon(
        isFrame ? Icons.person_rounded : product.icon,
        color: colour,
        size: size * 0.46,
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _CardButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusSm),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: context.appTextStyles.badge),
        ),
      ),
    );
  }
}

/// The purchase check: what you are buying, what it costs, what is left.
class _ConfirmSheet extends StatelessWidget {
  final ShopProduct product;
  final int coins;

  const _ConfirmSheet({required this.product, required this.coins});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final left = coins - product.price;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ItemArt(product: product, size: 88),
            const SizedBox(height: AppSpacing.md),
            Text('Buy ${product.name}?', style: styles.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _SheetRow(label: 'Price', value: '${product.price} coins'),
            _SheetRow(
              label: 'Your balance',
              value: '$coins coins',
              muted: true,
            ),
            _SheetRow(
              label: 'After buying',
              value: '$left coins',
              color: left >= 0 ? colors.success : colors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Confirm Purchase'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final Color? color;

  const _SheetRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: styles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          ),
          Text(
            value,
            style: styles.labelLarge.copyWith(
              color: color ?? (muted ? colors.textSecondary : null),
            ),
          ),
        ],
      ),
    );
  }
}
