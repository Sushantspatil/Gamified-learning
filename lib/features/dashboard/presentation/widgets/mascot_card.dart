import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/character_glow.dart';

/// Dashboard card with the 3D character beside a short line about what is
/// waiting for the player. The character waves when it appears, now and then
/// looks around or waves again, and reacts when tapped. While it loads, a
/// still picture of it is shown; if 3D cannot run, a plain icon takes its
/// place and the card still reads fine.
class MascotCard extends StatefulWidget {
  final String displayName;
  final int streak;

  /// A chest has been earned and is waiting to be opened.
  final bool chestReady;

  /// Today's free spin has not been used.
  final bool canSpin;

  /// What the player has equipped.
  final Character3dCosmetics cosmetics;

  /// The main call to action under the greeting; hidden when null.
  final VoidCallback? onPlay;

  const MascotCard({
    super.key,
    required this.displayName,
    required this.streak,
    this.chestReady = false,
    this.canSpin = false,
    this.cosmetics = Character3dCosmetics.none,
    this.onPlay,
  });

  /// The line shown under the greeting, by what matters most right now.
  static String messageFor({
    required int streak,
    required bool chestReady,
    required bool canSpin,
  }) {
    if (chestReady) return 'A chest is ready to open. Take a look!';
    if (canSpin) return 'Your free daily spin is waiting.';
    if (streak > 0) return 'You are on a $streak-day streak. Keep it going!';
    return 'Pick a subject and start your streak today.';
  }

  @override
  State<MascotCard> createState() => _MascotCardState();
}

class _MascotCardState extends State<MascotCard> {
  static const double _characterWidth = 132;
  static const double _characterHeight = 170;

  final Character3dController _character = Character3dController();
  int _taps = 0;

  /// Tapping cycles through a few friendly reactions.
  static const _reactions = [
    Character3dAction.wave,
    Character3dAction.clap,
    Character3dAction.cheer,
    Character3dAction.lookAround,
  ];

  void _react() {
    _character.play(_reactions[_taps % _reactions.length]);
    _taps++;
  }

  @override
  void dispose() {
    _character.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final firstName = widget.displayName.trim().split(RegExp(r'\s+')).first;
    final message = MascotCard.messageFor(
      streak: widget.streak,
      chestReady: widget.chestReady,
      canSpin: widget.canSpin,
    );

    return AppCard(
      key: const Key('mascot_card'),
      variant: AppCardVariant.tinted,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            key: const Key('mascot_tap'),
            behavior: HitTestBehavior.opaque,
            onTap: _react,
            child: CharacterGlow(
              strength: 1.35,
              child: Character3dView(
                width: _characterWidth,
                height: _characterHeight,
                state: Character3dState.idle,
                controller: _character,
                cosmetics: widget.cosmetics,
                ambient: true,
                initialAction: Character3dAction.wave,
                placeholder: const Character3dPoster(height: _characterHeight),
                fallback: Icon(
                  Icons.sports_esports_rounded,
                  size: 56,
                  color: colors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  firstName.isEmpty
                      ? 'Ready to learn?'
                      : "Let's go, $firstName!",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.headingSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: styles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (widget.onPlay != null) ...[
                  const SizedBox(height: AppSpacing.ms),
                  _PlayButton(onTap: widget.onPlay!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's main button: start playing.
class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: AppPressable(
        key: const Key('mascot_play'),
        onTap: onTap,
        borderRadius: AppDimensions.radiusCircular,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.primary, colors.violet]),
            borderRadius: AppDimensions.radiusCircular,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: colors.primaryForeground,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Play',
                  style: context.appTextStyles.labelLarge.copyWith(
                    color: colors.primaryForeground,
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
