import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/stage_backdrop.dart';
import '../../../rewards/presentation/widgets/live_balance_chip.dart';
import '../chest_style.dart';

/// The top of the Chest Box: the chest that matters right now (the one ready to
/// open, or else the next one to be earned) large on a lit stage, with a line
/// saying what to do and, when it is ready, a button to open it.
///
/// The chest floats gently for a few seconds and then rests (the motion is
/// finite on purpose, so it never keeps the screen busy forever).
class ChestHero extends StatefulWidget {
  final ChestStyle style;

  /// Whether this chest can be opened now (otherwise it is locked).
  final bool ready;

  /// "A chest is ready. Tap it to open!" or "Next: Golden Chest in 3 games".
  final String status;

  /// Opens it (a ready chest) or offers to buy it (a locked one).
  final VoidCallback onTap;

  const ChestHero({
    super.key,
    required this.style,
    required this.ready,
    required this.status,
    required this.onTap,
  });

  @override
  State<ChestHero> createState() => _ChestHeroState();
}

class _ChestHeroState extends State<ChestHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!AppMotion.reduceMotion(context)) {
      _float.repeat(reverse: true, count: 8);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final style = widget.style;
    // A short screen gets a shorter stage, so the chests below stay in reach.
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Column(
      children: [
        SizedBox(
          height: compact ? 150 : 206,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The light stays inside the stage and fades out towards its edges
              // (the sides first, then the bottom).
              Positioned.fill(
                child: ClipRect(
                  child: _Fade(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    fadeIn: true,
                    stops: const [0, 0.22, 0.78, 1],
                    child: _Fade(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      fadeIn: false,
                      stops: const [0, 0.55, 0.75, 1],
                      child: CustomPaint(
                        painter: StageBackdropPainter(
                          // A locked chest is lit more softly.
                          widget.ready
                              ? style.primary
                              : style.primary.withValues(alpha: 0.55),
                          centerY: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                right: 0,
                child: LiveBalanceChip(gems: true),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final height = math.min(
                    compact ? 100.0 : 138.0,
                    constraints.maxWidth * 0.5 / style.aspectRatio,
                  );
                  return Semantics(
                    button: true,
                    label: widget.ready
                        ? 'Open ${style.title}'
                        : '${style.title}, locked',
                    child: GestureDetector(
                      key: const Key('chest_hero'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTap,
                      child: AnimatedBuilder(
                        animation: _float,
                        builder: (context, child) {
                          final t = Curves.easeInOut.transform(_float.value);
                          return Transform.translate(
                            offset: Offset(0, -8 * t),
                            child: Transform.scale(
                              scale: widget.ready ? 1 + 0.035 * t : 1,
                              child: child,
                            ),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            ChestArt(
                              style: style,
                              height: height,
                              locked: !widget.ready,
                            ),
                            if (!widget.ready)
                              Positioned(
                                right: -4,
                                bottom: 4,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.surface,
                                    border: Border.all(
                                      color: style.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.lock_rounded,
                                      size: 20,
                                      color: style.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.status,
          key: const Key('chest_status'),
          textAlign: TextAlign.center,
          style: styles.titleLarge.copyWith(
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        if (widget.ready) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('chest_hero_open'),
            style: FilledButton.styleFrom(
              backgroundColor: style.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md - 2,
              ),
              textStyle: styles.labelLarge.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: widget.onTap,
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Open chest'),
          ),
        ],
      ],
    );
  }
}

/// The closed chest artwork; a locked one is drained of most of its colour.
class ChestArt extends StatelessWidget {
  final ChestStyle style;
  final double height;
  final bool locked;

  const ChestArt({
    super.key,
    required this.style,
    required this.height,
    required this.locked,
  });

  // Keeps about a quarter of the colour.
  static const _muted = ColorFilter.matrix(<double>[
    0.5, 0.4, 0.1, 0, 0, //
    0.3, 0.6, 0.1, 0, 0, //
    0.3, 0.4, 0.3, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      style.frameAsset(ChestFrame.closed),
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => SizedBox(height: height),
    );
    if (!locked) return image;
    return ColorFiltered(
      colorFilter: _muted,
      child: Opacity(opacity: 0.8, child: image),
    );
  }
}

/// Fades [child] out towards the end of a line (a mask, not a tint). With
/// [fadeIn] it fades in from the start as well.
class _Fade extends StatelessWidget {
  final Alignment begin;
  final Alignment end;
  final bool fadeIn;

  /// Four positions along the line, from 0 to 1.
  final List<double> stops;
  final Widget child;

  const _Fade({
    required this.begin,
    required this.end,
    required this.fadeIn,
    required this.stops,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: begin,
        end: end,
        colors: [
          fadeIn ? Colors.transparent : Colors.white,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: stops,
      ).createShader(rect),
      child: child,
    );
  }
}
