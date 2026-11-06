import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/character_glow.dart';

/// "You won N coins": the popup after a spin, dressed like the wheel (a gold
/// frame and glow on deep red in dark mode; cream and gold in light mode), with
/// the 3D character cheering at the top. The one on the screen behind is hidden
/// while this is open, so there is only ever one character.
Future<void> showWheelWinDialog(
  BuildContext context, {
  required int coins,
  required bool light,
  Character3dCosmetics cosmetics = Character3dCosmetics.none,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.66),
    builder: (context) =>
        _WheelWinDialog(coins: coins, light: light, cosmetics: cosmetics),
  );
}

class _WheelWinDialog extends StatelessWidget {
  final int coins;
  final bool light;
  final Character3dCosmetics cosmetics;

  const _WheelWinDialog({
    required this.coins,
    required this.light,
    required this.cosmetics,
  });

  static const Color _gold = Color(0xFFFFB900);

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final card = light
        ? const [Color(0xFFFFF7DE), Color(0xFFFFD98A)]
        : const [Color(0xFF8E1B12), Color(0xFF3A0508)];
    final frame = light ? const Color(0xFFD08A00) : _gold;
    final title = light ? const Color(0xFF5A1A00) : const Color(0xFFFFD34A);
    final body = light ? const Color(0xFF6B2A00) : Colors.white;
    final buttonBg = light ? const Color(0xFFB90000) : _gold;
    final buttonFg = light ? Colors.white : const Color(0xFF5A0A00);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          key: const Key('wheel_win_dialog'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: card,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: frame, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: frame.withValues(alpha: 0.55),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 156,
                  child: CharacterGlow(
                    color: _gold,
                    child: Character3dView(
                      width: 132,
                      height: 156,
                      state: Character3dState.idle,
                      initialAction: Character3dAction.cheer,
                      cosmetics: cosmetics,
                      placeholder: const SizedBox.shrink(),
                      arrive: true,
                      fallback: const Icon(
                        Icons.emoji_events_rounded,
                        size: 72,
                        color: _gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Congratulations!',
                  textAlign: TextAlign.center,
                  style: styles.headingSmall.copyWith(
                    color: title,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: AppColors.coinGold,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'You won $coins Coins.',
                        textAlign: TextAlign.center,
                        style: styles.body.copyWith(
                          color: body,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: buttonFg,
                      textStyle: styles.button.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('OK'),
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
