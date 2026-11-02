import 'package:flutter/material.dart';

import '../../../app/motion/app_motion.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../application/character_controller.dart';

/// One short line that fades in and out next to the character. It takes no
/// space from the question or options; the caller reserves its slot.
class CharacterSpeechBubble extends StatelessWidget {
  final CharacterController controller;

  const CharacterSpeechBubble({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return StreamBuilder<String?>(
      stream: controller.speech,
      initialData: controller.currentSpeech,
      builder: (context, snapshot) {
        final line = snapshot.data;
        return AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.fast),
          child: line == null
              ? const SizedBox.shrink(key: ValueKey('no-speech'))
              : DecoratedBox(
                  key: ValueKey(line),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: AppDimensions.radiusMd,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.ms,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
