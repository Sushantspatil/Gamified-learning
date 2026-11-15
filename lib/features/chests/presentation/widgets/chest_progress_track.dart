import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../rewards/domain/rewards_models.dart';
import '../chest_style.dart';

/// The 10-game cycle as ten chunky segments, coloured by the chest each one
/// leads to (gold, then cyber blue, then galaxy purple), with a small picture of
/// every chest where it is earned. Filled segments are games already played.
class ChestProgressTrack extends StatelessWidget {
  final RewardsState state;

  const ChestProgressTrack({super.key, required this.state});

  static const double _barHeight = 14;
  static const double _miniHeight = 30;

  ChestTier _tierOfSegment(int number) {
    for (final tier in ChestTier.values) {
      if (number <= tier.unlockAt) return tier;
    }
    return ChestTier.values.last;
  }

  /// Whether game number [number] (1-based) counts as played: either the
  /// progress has reached it, or the chest it leads to is waiting to be opened.
  bool _filled(int number) {
    if (number <= state.chestProgress) return true;
    final tier = _tierOfSegment(number);
    return state.chestReady(tier) && number <= tier.unlockAt;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final reduce = AppMotion.reduceMotion(context);
    const total = RewardsState.chestCycle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final segment = width / total;

        return SizedBox(
          height: _miniHeight + _barHeight + 32,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The chest pictures, above the segment where each is earned.
              for (final tier in ChestTier.values)
                Positioned(
                  left: segment * tier.unlockAt - segment / 2 - 24,
                  width: 48,
                  top: 0,
                  child: _MiniChest(
                    style: ChestStyle.of(tier),
                    earned:
                        state.chestProgress >= tier.unlockAt ||
                        state.chestReady(tier),
                    height: _miniHeight,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: _miniHeight + 8,
                child: Row(
                  key: const Key('chest_track'),
                  children: [
                    for (var n = 1; n <= total; n++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: n == total ? 0 : 4),
                          child: _Segment(
                            color: ChestStyle.of(_tierOfSegment(n)).primary,
                            filled: _filled(n),
                            animate: !reduce,
                            delay: n,
                            height: _barHeight,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // The game numbers where chests are earned.
              for (final tier in ChestTier.values)
                Positioned(
                  left: segment * tier.unlockAt - segment / 2 - 14,
                  width: 28,
                  top: _miniHeight + _barHeight + 12,
                  child: Text(
                    '${tier.unlockAt}',
                    textAlign: TextAlign.center,
                    style: styles.caption.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  final Color color;
  final bool filled;
  final bool animate;
  final int delay;
  final double height;

  const _Segment({
    required this.color,
    required this.filled,
    required this.animate,
    required this.delay,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    Widget bar(double fill) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: Color.lerp(colors.surfaceElevated, color, fill),
        boxShadow: fill > 0.5
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45 * fill),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: SizedBox(height: height),
    );

    if (!animate) return bar(filled ? 1 : 0);
    // Filled segments light up one after another.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: filled ? 1 : 0),
      duration: Duration(milliseconds: 260 + delay * 40),
      curve: Curves.easeOut,
      builder: (context, value, _) => bar(value),
    );
  }
}

class _MiniChest extends StatelessWidget {
  final ChestStyle style;
  final bool earned;
  final double height;

  const _MiniChest({
    required this.style,
    required this.earned,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1 : 0.45,
      child: Image.asset(
        style.frameAsset(ChestFrame.closed),
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => SizedBox(height: height),
      ),
    );
  }
}
