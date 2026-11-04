import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../character3d/presentation/character_3d_view.dart';

/// Dashboard card with the 3D character walking beside a short welcome line.
/// While the character loads, or if it cannot run on this device, a plain
/// icon takes its place and the card still reads fine.
class MascotCard extends StatelessWidget {
  final String displayName;
  final int streak;

  const MascotCard({
    super.key,
    required this.displayName,
    required this.streak,
  });

  static const double _characterWidth = 120;
  static const double _characterHeight = 150;

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final firstName = displayName.trim().split(RegExp(r'\s+')).first;
    final message = streak > 0
        ? 'You are on a $streak-day streak. Keep it going!'
        : 'Pick a subject and start your streak today.';

    return AppCard(
      key: const Key('mascot_card'),
      variant: AppCardVariant.tinted,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Character3dView(
            width: _characterWidth,
            height: _characterHeight,
            state: Character3dState.walk,
            fallback: Icon(
              Icons.sports_esports_rounded,
              size: 56,
              color: colors.primary,
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
                Text(
                  message,
                  style: styles.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
