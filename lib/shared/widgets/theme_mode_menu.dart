import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/theme_mode_controller.dart';

class ThemeModeMenu extends ConsumerWidget {
  const ThemeModeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPreference = ref.watch(themeModeControllerProvider);
    final colors = context.themeColors;
    final nextPreference = selectedPreference == AppThemePreference.dark
        ? AppThemePreference.light
        : AppThemePreference.dark;

    return IconButton(
      tooltip: 'Switch to ${nextPreference.label.toLowerCase()} mode',
      style: IconButton.styleFrom(
        foregroundColor: colors.textPrimary,
        backgroundColor: colors.surfaceElevated,
        hoverColor: colors.surfaceHover,
        focusColor: colors.primary.withValues(alpha: 0.12),
        highlightColor: colors.primary.withValues(alpha: 0.12),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        ref.read(themeModeControllerProvider.notifier).toggleTheme();
      },
      icon: AnimatedSwitcher(
        duration: AppMotion.duration(context, AppMotion.normal),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return RotationTransition(
            turns: Tween<double>(begin: 0.18, end: 0).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: ScaleTransition(scale: curvedAnimation, child: child),
            ),
          );
        },
        child: Icon(selectedPreference.icon, key: ValueKey(selectedPreference)),
      ),
    );
  }
}
