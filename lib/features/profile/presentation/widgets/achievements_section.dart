import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../achievements.dart';

/// A grid of badges: lit once earned, grey with a progress bar until then.
/// Tapping one says what it takes to earn it.
class AchievementsSection extends StatelessWidget {
  final List<Achievement> items;

  const AchievementsSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final unlocked = items.where((a) => a.unlocked).length;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Achievements',
                style: styles.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$unlocked/${items.length}',
              key: const Key('achievements_count'),
              style: styles.labelLarge.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.ms,
            crossAxisSpacing: AppSpacing.ms,
            mainAxisExtent: 124 * scale,
          ),
          itemBuilder: (context, index) => _BadgeTile(
            achievement: items[index],
            onTap: () => _showDetail(context, items[index]),
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, Achievement a) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.themeColors.surface,
      builder: (context) => _BadgeDetail(achievement: a),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;

  const _BadgeTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final a = achievement;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusCard,
          border: Border.all(
            color: a.unlocked ? a.color.withValues(alpha: 0.7) : colors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              _BadgeIcon(achievement: a, size: 52),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Center(
                  child: Text(
                    a.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: styles.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: a.unlocked
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (!a.unlocked)
                AppProgressBar(
                  value: a.progress,
                  height: 4,
                  accentColor: a.color,
                  semanticLabel: '${a.title} progress',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final Achievement achievement;
  final double size;

  const _BadgeIcon({required this.achievement, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final a = achievement;
    final on = a.unlocked;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: on
                ? RadialGradient(
                    colors: [
                      a.color.withValues(alpha: 0.38),
                      a.color.withValues(alpha: 0.12),
                    ],
                  )
                : null,
            color: on ? null : colors.surfaceElevated,
            border: Border.all(
              color: on ? a.color : colors.borderStrong,
              width: on ? 2 : 1,
            ),
            boxShadow: [
              if (on)
                BoxShadow(
                  color: a.color.withValues(alpha: 0.35),
                  blurRadius: size * 0.3,
                ),
            ],
          ),
          child: Icon(
            a.icon,
            size: size * 0.5,
            color: on ? a.color : colors.textMuted,
          ),
        ),
        if (!on)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderStrong),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: size * 0.22,
                color: colors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeDetail extends StatelessWidget {
  final Achievement achievement;

  const _BadgeDetail({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final a = achievement;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgeIcon(achievement: a, size: 84),
            const SizedBox(height: AppSpacing.md),
            Text(a.title, style: styles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              a.description,
              textAlign: TextAlign.center,
              style: styles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (a.unlocked)
              Text(
                'Unlocked!',
                style: styles.labelLarge.copyWith(color: colors.success),
              )
            else ...[
              AppProgressBar(
                value: a.progress,
                height: 8,
                accentColor: a.color,
                semanticLabel: '${a.title} progress',
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                a.progressLabel,
                style: styles.labelLarge.copyWith(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
