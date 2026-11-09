import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme_colors.dart';
import '../../features/analytics/data/analytics_service.dart';
import '../../features/analytics/presentation/analytics_providers.dart';

/// "MCQ Quiz" becomes "mcq-quiz": a short identifier safe to report.
String gameModeId(String mode) => mode
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Tells analytics the player left a game half way. Never throws: a screen with
/// no provider scope (some tests) simply reports nothing.
void _reportQuit(BuildContext context, String mode) {
  try {
    ProviderScope.containerOf(context, listen: false)
        .read(analyticsServiceProvider)
        .track(AnalyticsEvents.gameQuit, {'mode': gameModeId(mode)});
  } catch (_) {}
}

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
  if (leave == true && context.mounted) _reportQuit(context, mode);
  return leave == true;
}
