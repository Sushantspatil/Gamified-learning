import 'package:flutter/material.dart';

import '../../app/theme/app_theme_colors.dart';

/// The one "leave this game?" question every mode asks when the player uses the
/// back gesture or button during a round. Returns true to leave.
Future<bool> confirmQuitGame(
  BuildContext context, {
  required String mode,
}) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('quit_game_dialog'),
      title: Text('Quit $mode?'),
      content: const Text('Your progress in this round will be lost.'),
      actions: [
        TextButton(
          key: const Key('quit_game_keep'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep playing'),
        ),
        TextButton(
          key: const Key('quit_game_leave'),
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: ctx.themeColors.error),
          child: const Text('Quit'),
        ),
      ],
    ),
  );
  return leave == true;
}
