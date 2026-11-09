import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../habit/domain/next_step.dart';
import '../../../../habit/presentation/next_step_providers.dart';
import '../../../../habit/presentation/next_step_widgets.dart';
import '../../../domain/entities/quiz_result.dart';
import '../../../domain/result_flow.dart';

/// Decides whether the progress screen is needed and hands that to [builder].
/// With no provider scope (some tests render the result on its own) there is
/// never a progress screen.
class ResultProgressGate extends StatelessWidget {
  final bool leveledUp;
  final Widget Function(BuildContext context, bool hasProgress) builder;

  const ResultProgressGate({
    super.key,
    required this.leveledUp,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      return builder(context, false);
    }
    return _Gate(leveledUp: leveledUp, builder: builder);
  }
}

class _Gate extends ConsumerWidget {
  final bool leveledUp;
  final Widget Function(BuildContext context, bool hasProgress) builder;

  const _Gate({required this.leveledUp, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NextStep? step = ref.watch(nextStepProvider);
    return builder(
      context,
      resultNeedsProgressBeat(leveledUp: leveledUp, step: step),
    );
  }
}

/// The second screen of a result, shown only when something changed: a level-up
/// with its XP bar, and the daily goals (a finished goal to collect, or the
/// next one a step closer).
class ResultProgressScreen extends StatelessWidget {
  final bool leveledUp;
  final QuizLevelProgress? levelProgress;
  final int earnedXp;

  const ResultProgressScreen({
    super.key,
    required this.leveledUp,
    required this.levelProgress,
    required this.earnedXp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('result_progress'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (levelProgress != null)
          _LevelBlock(
            progress: levelProgress!,
            earnedXp: earnedXp,
            leveledUp: leveledUp,
          ),
        // The goals part shows itself only when there is something to say.
        const NextStepPanel(large: true),
      ],
    );
  }
}

class _LevelBlock extends StatelessWidget {
  final QuizLevelProgress progress;
  final int earnedXp;
  final bool leveledUp;

  const _LevelBlock({
    required this.progress,
    required this.earnedXp,
    required this.leveledUp,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        children: [
          if (leveledUp)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Level up!',
                key: const Key('result_level_up'),
                style: styles.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.xpPurple,
                ),
              ),
            ),
          Row(
            children: [
              Text(
                'Level ${progress.currentLevel}',
                style: styles.titleMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '+$earnedXp XP',
                style: styles.labelLarge.copyWith(
                  color: AppColors.xpPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 14,
                value: value,
                backgroundColor: colors.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.xpPurple,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${progress.experience} / ${progress.nextLevelExperience} XP',
              style: styles.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
