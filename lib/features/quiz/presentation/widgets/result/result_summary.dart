import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/motion/app_motion.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../shared/widgets/animated_count_text.dart';
import '../../../domain/result_outcome.dart';

/// One of the three numbers on the result screen, drawn as a chunky "sticker"
/// tile: an icon, the number, and a small label.
class ResultTileData {
  /// "XP", "ACCURACY", "TIME"...
  final String label;
  final IconData icon;
  final Color color;

  /// A number that counts up (with [prefix] and [suffix] around it)...
  final int? number;
  final String prefix;
  final String suffix;

  /// ...or ready-made text (for example a time like "1:42").
  final String? text;

  const ResultTileData.number({
    required this.label,
    required this.icon,
    required this.color,
    required int this.number,
    this.prefix = '',
    this.suffix = '',
  }) : text = null;

  const ResultTileData.text({
    required this.label,
    required this.icon,
    required this.color,
    required String this.text,
  }) : number = null,
       prefix = '',
       suffix = '';
}

/// The first screen of a result: the character on a lit stage, a headline that
/// uses the player's name, the score as the biggest thing on the screen, a dot
/// for every answer, three tiles and the coins. The rest is on the next screen,
/// behind "Review your answers", or behind "Score details".
class ResultSummary extends StatelessWidget {
  final ResultOutcome outcome;
  final Widget mascot;

  /// The colour of the mood: calm blue after a poor game, gold for a brilliant
  /// one, fiery for Sudden Death, the brand colour otherwise.
  final Color accent;

  /// The player's first name, for "Great job, Ada!". Null leaves it out.
  final String? playerName;

  /// The small line above the headline, e.g. "ROUND COMPLETE".
  final String eyebrow;

  final int points;

  /// The most the game could score, or null/0 when there is no fixed maximum.
  final int? maxPoints;

  /// Exactly three tiles.
  final List<ResultTileData> tiles;
  final int coins;

  /// "New personal best!" or nothing.
  final Widget? bestBadge;

  /// The row of right/wrong dots, or nothing.
  final Widget? answers;

  const ResultSummary({
    super.key,
    required this.outcome,
    required this.mascot,
    required this.accent,
    required this.points,
    required this.tiles,
    required this.coins,
    this.maxPoints,
    this.playerName,
    this.eyebrow = 'ROUND COMPLETE',
    this.bestBadge,
    this.answers,
  });

  /// "Great job!" becomes "Great job, Ada!".
  String get headlineText {
    final name = playerName;
    if (name == null || name.isEmpty) return outcome.headline;
    final base = outcome.headline.replaceAll(RegExp(r'[!.]+$'), '');
    return '$base, $name!';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final hasMax = maxPoints != null && maxPoints! > 0;

    return Column(
      key: const Key('result_summary'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _Stage(accent: accent, child: mascot),
        const SizedBox(height: AppSpacing.sm),
        Text(
          eyebrow,
          style: styles.labelSmall.copyWith(
            color: colors.textSecondary,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          headlineText,
          key: const Key('result_headline'),
          textAlign: TextAlign.center,
          style: styles.displayMedium.copyWith(
            fontSize: 34,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        if (outcome.detail != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            outcome.detail!,
            textAlign: TextAlign.center,
            style: styles.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // The score: the biggest thing on the screen.
        Row(
          key: const Key('result_points'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedCountText(
              value: points,
              duration: const Duration(milliseconds: 1000),
              style: styles.display.copyWith(
                fontSize: 76,
                height: 1,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              hasMax ? '/ $maxPoints pts' : 'points',
              style: styles.titleMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (bestBadge != null) ...[
          const SizedBox(height: AppSpacing.sm),
          bestBadge!,
        ],
        if (answers != null) ...[
          const SizedBox(height: AppSpacing.md),
          answers!,
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          key: const Key('result_tiles'),
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Transform.rotate(
                  // A hair off-level, like stickers stuck on by hand.
                  angle: switch (i) {
                    0 => -0.025,
                    2 => 0.025,
                    _ => 0.0,
                  },
                  child: _Tile(data: tiles[i], delayIndex: i),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _CoinsChip(coins: coins),
      ],
    );
  }
}

/// A lit stage for the character: a soft glow, rays fanning out behind it, and
/// a glowing disc on the floor.
class _Stage extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _Stage({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('result_stage'),
      height: 230,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _StagePainter(accent))),
          Positioned(bottom: 6, child: child),
        ],
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  final Color accent;

  _StagePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    final reach = size.width * 0.9;

    // Rays: thin wedges around the centre that fade out towards the edge.
    const rays = 16;
    final wedge = 2 * math.pi / rays / 2;
    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: reach));
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + reach * math.cos(a - wedge / 2),
          center.dy + reach * math.sin(a - wedge / 2),
        )
        ..lineTo(
          center.dx + reach * math.cos(a + wedge / 2),
          center.dy + reach * math.sin(a + wedge / 2),
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // The glow right behind the character.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.5), accent.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.4));
    canvas.drawCircle(center, size.width * 0.4, glow);

    // The floor under the character's feet.
    final floor = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 14),
      width: size.width * 0.5,
      height: 26,
    );
    canvas.drawOval(
      floor,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.65), accent.withValues(alpha: 0)],
        ).createShader(floor),
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) => old.accent != accent;
}

class _Tile extends StatelessWidget {
  final ResultTileData data;
  final int delayIndex;

  const _Tile({required this.data, required this.delayIndex});

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final valueStyle = styles.titleLarge.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w900,
      color: colors.textPrimary,
    );

    final tile = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Color.alphaBlend(
          data.color.withValues(alpha: 0.18),
          colors.cardBackground,
        ),
        border: Border.all(color: data.color, width: 2),
        // A solid edge underneath: the tile looks like it has thickness.
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.75),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: data.color, size: 26),
            const SizedBox(height: AppSpacing.xs),
            data.number != null
                ? AnimatedCountText(
                    value: data.number!,
                    prefix: data.prefix,
                    suffix: data.suffix,
                    duration: const Duration(milliseconds: 800),
                    textAlign: TextAlign.center,
                    style: valueStyle,
                  )
                : Text(
                    data.text!,
                    textAlign: TextAlign.center,
                    style: valueStyle,
                  ),
            const SizedBox(height: 2),
            Text(
              data.label,
              textAlign: TextAlign.center,
              style: styles.labelSmall.copyWith(
                color: data.color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );

    if (AppMotion.reduceMotion(context)) return tile;
    // The tiles pop up one after another.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delayIndex * 150),
      curve: Interval(delayIndex * 0.15, 1, curve: Curves.easeOutBack),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 24),
          child: child,
        ),
      ),
      child: tile,
    );
  }
}

class _CoinsChip extends StatelessWidget {
  final int coins;

  const _CoinsChip({required this.coins});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('result_coins'),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              color: AppColors.coinGold,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.xs),
            AnimatedCountText(
              value: coins,
              prefix: '+',
              suffix: ' Coins',
              duration: const Duration(milliseconds: 800),
              style: context.appTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
