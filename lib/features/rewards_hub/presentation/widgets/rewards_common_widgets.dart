import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/rewards_models.dart';
import '../providers/rewards_providers.dart';

/// Coin balance pill driven by the shared rewards state.
class CoinBalanceChip extends ConsumerWidget {
  const CoinBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(rewardsProvider.select((s) => s.coins));
    final colors = context.themeColors;

    return Semantics(
      label: 'Coin balance $coins',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.coinGold.withValues(alpha: 0.14),
          borderRadius: AppDimensions.radiusCircular,
          border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.ms,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                size: 20,
                color: AppColors.coinGold,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              AnimatedCountText(
                value: coins,
                style: context.appTextStyles.labelLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round icon badge used for rewards, products and history rows.
class RewardIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const RewardIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: color, size: size * 0.52),
      ),
    );
  }
}

/// Shows the reward celebration. Completes when the student taps Collect
/// (or dismisses the dialog).
Future<void> showRewardPopup(
  BuildContext context, {
  required String heading,
  required List<RewardItem> rewards,
  String? subtitle,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        RewardPopup(heading: heading, subtitle: subtitle, rewards: rewards),
  );
}

class RewardPopup extends StatefulWidget {
  final String heading;
  final String? subtitle;
  final List<RewardItem> rewards;

  const RewardPopup({
    super.key,
    required this.heading,
    required this.rewards,
    this.subtitle,
  });

  @override
  State<RewardPopup> createState() => _RewardPopupState();
}

class _RewardPopupState extends State<RewardPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-shot: only starts once, never restarts on rebuild.
    if (!_burst.isAnimating && _burst.value == 0) {
      if (AppMotion.reduceMotion(context)) {
        _burst.value = 1;
      } else {
        _burst.forward();
      }
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final main = widget.rewards.first;

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: AppDimensions.radiusLg,
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 132,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _BurstPainter(
                            progress: _burst,
                            color: main.color,
                          ),
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: AppMotion.duration(
                        context,
                        AppMotion.celebration,
                      ),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: RewardIconBadge(
                        icon: main.icon,
                        color: main.color,
                        size: 88,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.heading,
                textAlign: TextAlign.center,
                style: styles.headingSmall,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: styles.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final reward in widget.rewards)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: reward.color.withValues(alpha: 0.1),
                      borderRadius: AppDimensions.radiusMd,
                      border: Border.all(
                        color: reward.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.ms,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(reward.icon, color: reward.color, size: 24),
                          const SizedBox(width: AppSpacing.ms),
                          Expanded(
                            child: Text(
                              reward.title,
                              style: styles.labelLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            reward.quantityLabel,
                            style: styles.labelLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Collect',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small confetti-like burst, drawn from a fixed particle table so it is
/// deterministic and cheap. Repaints only via the animation listenable.
class _BurstPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _BurstPainter({required this.progress, required this.color})
    : super(repaint: progress);

  static const int _count = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.value);
    if (progress.value >= 1) return;
    final center = size.center(Offset.zero);
    final fade = (1 - progress.value).clamp(0.0, 1.0);
    final maxRadius = math.min(size.width / 2, size.height / 2 + 24);
    final palette = [color, AppColors.coinGold, AppColors.secondary];

    for (var i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * math.pi + (i.isEven ? 0.1 : -0.1);
      final distance = maxRadius * (0.45 + 0.55 * t) * (i % 3 == 0 ? 0.8 : 1);
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = palette[i % palette.length].withValues(alpha: fade);
      canvas.drawCircle(position, i.isEven ? 3.5 : 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
