import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/motion/app_motion.dart';
import '../../../app/router/route_names.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_pressable.dart';
import '../../../shared/widgets/app_progress_bar.dart';
import '../domain/next_step.dart';
import 'next_step_providers.dart';

/// On the home screen: the one thing to do next, with a big button. Left out
/// until the server has sent goals, so a server without them changes nothing.
class NextStepCard extends ConsumerWidget {
  const NextStepCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(nextStepProvider);
    if (step == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: _NextStepBody(
        key: const Key('next_step_card'),
        step: step,
        playLabel: 'Play now',
        onPlay: () => context.go(RouteNames.practice),
      ),
    );
  }
}

/// At the end of a game: what the game just did for today's goals and streak,
/// and what to do next. A reward that is ready can be collected right here.
///
/// It quietly shows nothing where there is no provider scope (some tests render
/// the result screens on their own) or no goals from the server.
class NextStepPanel extends StatelessWidget {
  const NextStepPanel({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return const _NextStepPanelBody();
  }
}

class _NextStepPanelBody extends ConsumerWidget {
  const _NextStepPanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(nextStepProvider);
    if (step == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: _NextStepBody(
        key: const Key('next_step_panel'),
        step: step,
        heading: 'Up next',
      ),
    );
  }
}

/// The shared look: an icon, a headline, a detail line, an optional progress bar
/// and an optional button.
class _NextStepBody extends ConsumerStatefulWidget {
  final NextStep step;
  final String? heading;

  /// A "Play" button for steps that are about playing; null leaves it out.
  final String? playLabel;
  final VoidCallback? onPlay;

  const _NextStepBody({
    super.key,
    required this.step,
    this.heading,
    this.playLabel,
    this.onPlay,
  });

  @override
  ConsumerState<_NextStepBody> createState() => _NextStepBodyState();
}

class _NextStepBodyState extends ConsumerState<_NextStepBody> {
  bool _collecting = false;

  Future<void> _collect() async {
    if (_collecting) return;
    final step = widget.step;
    final label = rewardLabelOf(step);
    setState(() => _collecting = true);
    final problem = await collectNextStep(ref, step);
    if (!mounted) return;
    setState(() => _collecting = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(problem ?? '$label collected!')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final view = _viewOf(widget.step, colors);

    final isCollect =
        widget.step is CollectGoal || widget.step is CollectStreakReward;
    String? actionLabel;
    VoidCallback? action;
    if (isCollect) {
      actionLabel = 'Collect ${rewardLabelOf(widget.step)}';
      action = _collecting ? null : _collect;
    } else if (widget.playLabel != null && widget.step is ContinueGoal) {
      actionLabel = widget.playLabel;
      action = widget.onPlay;
    }

    return _Reveal(
      child: AppCard(
        variant: AppCardVariant.tinted,
        tintColor: view.accent,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.heading != null) ...[
              Text(
                widget.heading!,
                style: styles.labelSmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: view.accent.withValues(alpha: 0.16),
                  ),
                  child: Icon(view.icon, color: view.accent, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.title,
                        key: const Key('next_step_title'),
                        style: styles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        view.detail,
                        key: const Key('next_step_detail'),
                        style: styles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (view.progress != null) ...[
              const SizedBox(height: AppSpacing.md),
              _FillIn(
                value: view.progress!,
                color: view.accent,
                label: view.detail,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ActionButton(
                key: const Key('next_step_action'),
                label: actionLabel,
                color: view.accent,
                busy: _collecting,
                onTap: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What a step looks like: its words, colour, icon and progress.
class _StepView {
  final String title;
  final String detail;
  final IconData icon;
  final Color accent;
  final double? progress;

  const _StepView({
    required this.title,
    required this.detail,
    required this.icon,
    required this.accent,
    this.progress,
  });
}

_StepView _viewOf(NextStep step, AppThemeColors colors) {
  switch (step) {
    case CollectGoal(:final mission, :final readyCount):
      return _StepView(
        title: readyCount > 1 ? '$readyCount rewards ready!' : 'Goal complete!',
        detail: readyCount > 1 ? 'Including: ${mission.title}' : mission.title,
        icon: Icons.emoji_events_rounded,
        accent: colors.warning,
      );
    case CollectStreakReward(:final milestone, :final readyCount):
      return _StepView(
        title: readyCount > 1
            ? '$readyCount rewards ready!'
            : '${milestone.days}-day streak reward!',
        detail: 'Your streak earned a bonus',
        icon: Icons.local_fire_department_rounded,
        accent: colors.warning,
      );
    case ContinueGoal(:final mission, :final goalsDone, :final goalsTotal):
      final remaining = mission.targetCount - mission.progressCount;
      return _StepView(
        title: mission.title,
        detail:
            '${mission.progressCount} of ${mission.targetCount}'
            ' · ${mission.rewardLabel}'
            '${goalsTotal > 1 ? ' · $goalsDone of $goalsTotal goals done' : ''}',
        icon: remaining <= 1 ? Icons.bolt_rounded : Icons.flag_rounded,
        accent: colors.primary,
        progress: mission.targetCount == 0
            ? 0
            : mission.progressCount / mission.targetCount,
      );
    case AllGoalsDone(:final nextStreakReward, :final daysToNextStreakReward):
      return _StepView(
        title: 'All goals done today!',
        detail: nextStreakReward == null
            ? 'New goals tomorrow. See you then!'
            : '$daysToNextStreakReward more '
                  '${daysToNextStreakReward == 1 ? 'day' : 'days'} for the '
                  '${nextStreakReward.days}-day streak reward '
                  '(${nextStreakReward.rewardLabel})',
        icon: Icons.verified_rounded,
        accent: colors.success,
      );
  }
}

/// Fades in and slides up a little when it first appears.
class _Reveal extends StatelessWidget {
  final Widget child;

  const _Reveal({required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.duration(context, AppMotion.slow),
      curve: AppMotion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A progress bar that fills from empty when it first appears, so a goal
/// visibly ticks up as the player arrives on the screen.
class _FillIn extends StatelessWidget {
  final double value;
  final Color color;
  final String label;

  const _FillIn({
    required this.value,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return AppProgressBar(
        value: value,
        accentColor: color,
        semanticLabel: label,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: AppMotion.duration(context, AppMotion.celebration),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => AppProgressBar(
        value: animated,
        accentColor: color,
        semanticLabel: label,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCircular,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.ms,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppDimensions.radiusCircular,
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: context.appTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
