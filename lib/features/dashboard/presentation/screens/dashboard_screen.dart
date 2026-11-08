import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_elevation.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../chapters/domain/entities/topic.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../../daily_missions/domain/entities/daily_mission.dart';
import '../../../daily_missions/presentation/providers/daily_mission_providers.dart';
import '../../../daily_rewards/presentation/providers/daily_reward_providers.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../profile/presentation/avatar_catalog.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../streaks/domain/entities/streak.dart';
import '../../../streaks/presentation/widgets/streak_rewards_strip.dart';
import '../../../streaks/presentation/widgets/streak_week_row.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../../../core/utils/date_key.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../reminders/presentation/reminder_host.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../widgets/mascot_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final profile = ref.watch(profileControllerProvider).valueOrNull;
    final wallet = ref.watch(walletControllerProvider).valueOrNull;
    final streakAsync = ref.watch(streakControllerProvider);
    final selectedPathId = ref
        .watch(selectedLearningPathControllerProvider)
        .valueOrNull;
    final pathsAsync = ref.watch(learningPathsProvider);
    final rewards = ref.watch(rewardsProvider);

    return ReminderHost(
      child: GameScaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            // No side padding here: each block pads itself, so the subjects row
            // can run to the screen edges.
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 96),
            children: [
              _ScreenPadding(
                child: _ProfileHeader(
                  displayName: user?.displayName ?? 'Learner',
                  avatarId: profile?.avatarId ?? 'default',
                  classLevel: profile?.classLevel,
                  board: profile?.board,
                  level: profile?.level ?? 1,
                  streak: streakAsync.valueOrNull?.currentStreak ?? 0,
                  coins: wallet?.coins ?? 0,
                  gems: wallet?.gems ?? 0,
                  onTap: () => context.go(RouteNames.profile),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ScreenPadding(
                child: MascotCard(
                  displayName: user?.displayName ?? 'Learner',
                  streak: streakAsync.valueOrNull?.currentStreak ?? 0,
                  chestReady: rewards.anyChestReady,
                  canSpin: rewards.canSpinOn(
                    dateKey(ref.read(rewardsClockProvider)()),
                  ),
                  cosmetics: Character3dCosmetics.fromShopIds(
                    avatarId: rewards.equippedAvatar,
                    frameId: rewards.equippedFrame,
                  ),
                  onPlay: () => context.go(RouteNames.practice),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ScreenPadding(
                child: _SelectedPathDashboardSections(
                  selectedPathId: selectedPathId,
                  pathsAsync: pathsAsync,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ScreenPadding(
                child: _QuickPracticeSection(selectedPathId: selectedPathId),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _ScreenPadding(child: _RewardsSection()),
              const SizedBox(height: AppSpacing.lg),
              _ScreenPadding(child: _StreakSection(streakAsync: streakAsync)),
              const SizedBox(height: AppSpacing.lg),
              // Left out when there are no goals; it carries its own gap.
              const _ScreenPadding(child: _DailyGoalSection()),
              _SubjectsSection(
                pathsAsync: pathsAsync,
                selectedPathId: selectedPathId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPathDashboardSections extends ConsumerWidget {
  final String? selectedPathId;
  final AsyncValue<List<LearningPath>> pathsAsync;

  const _SelectedPathDashboardSections({
    required this.selectedPathId,
    required this.pathsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return pathsAsync.when(
      loading: () =>
          const _DashboardLoadingCard(label: 'Loading learning path'),
      error: (error, stackTrace) => const _DashboardMessageCard(
        message: 'Could not load your learning path.',
      ),
      data: (paths) {
        final path = _selectedPath(paths, selectedPathId);
        if (path == null || selectedPathId == null) {
          return _ChoosePathCard(
            onTap: () => context.go(RouteNames.learningPath),
          );
        }

        final chaptersAsync = ref.watch(chaptersProvider(selectedPathId!));

        return chaptersAsync.when(
          loading: () => _ContinueLearningCard(
            title: path.title,
            subtitle: path.description,
            completedTopics: 0,
            totalTopics: path.topicCount,
            onTap: () => context.go(RouteNames.learningPath),
          ),
          error: (error, stackTrace) => _ContinueLearningCard(
            title: path.title,
            subtitle: path.description,
            completedTopics: 0,
            totalTopics: path.topicCount,
            onTap: () => context.go(RouteNames.learningPath),
          ),
          data: (chapters) {
            final chapter = chapters.isEmpty ? null : chapters.first;
            if (chapter == null) {
              return _ContinueLearningCard(
                title: path.title,
                subtitle: path.description,
                completedTopics: 0,
                totalTopics: path.topicCount,
                onTap: () => context.go(RouteNames.learningPath),
              );
            }

            final topicsAsync = ref.watch(topicsProvider(chapter.id));
            return topicsAsync.when(
              loading: () => _ContinueLearningCard(
                title: path.title,
                subtitle: chapter.title,
                completedTopics: 0,
                totalTopics: chapter.topicCount,
                onTap: () => context.push(RouteNames.subjectLearnPath(path.id)),
              ),
              error: (error, stackTrace) => _ContinueLearningCard(
                title: path.title,
                subtitle: chapter.title,
                completedTopics: 0,
                totalTopics: chapter.topicCount,
                onTap: () => context.push(RouteNames.subjectLearnPath(path.id)),
              ),
              data: (topics) {
                final topic =
                    _firstIncompleteTopic(topics) ??
                    (topics.isEmpty ? null : topics.first);
                return _ContinueLearningCard(
                  title: path.title,
                  subtitle: topic == null
                      ? chapter.title
                      : '${chapter.title} - ${topic.title}',
                  completedTopics: 0,
                  totalTopics: chapter.topicCount,
                  onTap: topic == null
                      ? () => context.push(RouteNames.subjectLearnPath(path.id))
                      : () => context.push(
                          RouteNames.topicPath(chapter.id, topic.id),
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  LearningPath? _selectedPath(List<LearningPath> paths, String? id) {
    for (final path in paths) {
      if (path.id == id) return path;
    }
    return null;
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String avatarId;
  final String? classLevel;
  final String? board;
  final int level;
  final int streak;
  final int coins;
  final int gems;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.displayName,
    required this.avatarId,
    this.classLevel,
    this.board,
    required this.level,
    required this.streak,
    required this.coins,
    required this.gems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPressable(
          key: const Key('compact_profile_header'),
          onTap: onTap,
          borderRadius: AppDimensions.radiusMd,
          child: Row(
            children: [
              _LevelAvatar(avatarId: avatarId, level: level),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.titleLarge,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.waving_hand_outlined,
                          color: colors.warning,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppBadge(
                      label: _subtitle,
                      variant: AppBadgeVariant.primary,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        Row(
          children: [
            Expanded(
              child: _MetricPill(
                icon: Icons.local_fire_department,
                iconColor: AppColors.streakFire,
                value: streak,
                semanticLabel: 'Current streak',
                tooltip: 'Leaderboard',
                onTap: () => context.go(RouteNames.leaderboard),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricPill(
                icon: Icons.monetization_on_rounded,
                iconColor: AppColors.coinGold,
                value: coins,
                semanticLabel: 'Coins',
                tooltip: 'Wallet',
                onTap: () => context.push(RouteNames.wallet),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricPill(
                icon: Icons.diamond,
                iconColor: AppColors.gemCyan,
                value: gems,
                semanticLabel: 'Gems',
                tooltip: 'Shop',
                onTap: () => context.push(RouteNames.shop),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Class and board only: the level sits on the avatar.
  String get _subtitle {
    final details = [if (classLevel != null) 'Class $classLevel', ?board];
    if (details.isEmpty) return 'Level $level learner';
    return details.join(' - ');
  }
}

/// The player's avatar with their level as a small tag on its corner.
class _LevelAvatar extends StatelessWidget {
  final String avatarId;
  final int level;

  const _LevelAvatar({required this.avatarId, required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppAvatar(
          fallbackIcon: AvatarCatalog.iconFor(avatarId),
          size: AppDimensions.avatarSizeMd,
        ),
        Positioned(
          right: -8,
          bottom: -4,
          child: Semantics(
            label: 'Level',
            value: '$level',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: AppDimensions.radiusCircular,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  'Lv $level',
                  style: AppTypography.badge.copyWith(
                    color: colors.primaryForeground,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final String semanticLabel;
  final String? tooltip;
  final VoidCallback? onTap;

  const _MetricPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.semanticLabel,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    final content = Semantics(
      label: semanticLabel,
      value: value.toString(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppDimensions.radiusCircular,
          border: Border.all(color: colors.borderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedCountText(
                    value: value,
                    style: context.appTextStyles.labelLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final pressable = AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCircular,
      child: content,
    );

    if (tooltip == null) return pressable;
    return Tooltip(message: tooltip!, child: pressable);
  }
}

class _ContinueLearningCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int completedTopics;
  final int totalTopics;
  final VoidCallback onTap;

  const _ContinueLearningCard({
    required this.title,
    required this.subtitle,
    required this.completedTopics,
    required this.totalTopics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final progress = totalTopics == 0 ? 0.0 : completedTopics / totalTopics;
    final percent = (progress * 100).round();

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusLg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, colors.violet],
          ),
          borderRadius: AppDimensions.radiusLg,
          boxShadow: AppElevation.shadows(colors, 2),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -4,
              bottom: -6,
              child: Icon(
                Icons.library_books_outlined,
                color: colors.primaryForeground.withValues(alpha: 0.22),
                size: 90,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 86),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTINUE LEARNING',
                    style: AppTypography.badge.copyWith(
                      color: colors.primaryForeground.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.titleLarge.copyWith(
                      color: colors.primaryForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: colors.primaryForeground.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$completedTopics of $totalTopics topics',
                          style: context.appTextStyles.labelSmall.copyWith(
                            color: colors.primaryForeground.withValues(
                              alpha: 0.86,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: context.appTextStyles.labelSmall.copyWith(
                          color: colors.primaryForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppProgressBar(
                    value: progress,
                    height: 5,
                    accentColor: colors.primaryForeground,
                    trackColor: colors.primaryForeground.withValues(
                      alpha: 0.26,
                    ),
                    semanticLabel: 'Continue learning progress',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryForeground,
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
                          Text(
                            'Continue',
                            style: context.appTextStyles.labelLarge.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.arrow_forward,
                            color: colors.primary,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakSection extends StatelessWidget {
  final AsyncValue<Streak> streakAsync;

  const _StreakSection({required this.streakAsync});

  @override
  Widget build(BuildContext context) {
    final streak = streakAsync.valueOrNull ?? Streak.empty;
    final count = streak.currentStreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Your streak'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              StreakWeekRow(currentStreak: count),
              const SizedBox(height: AppSpacing.md),
              Text(
                count > 0
                    ? 'Play today to keep your streak alive'
                    : 'Play today to start your streak',
                textAlign: TextAlign.center,
                style: context.appTextStyles.bodyMedium.copyWith(
                  color: context.themeColors.textSecondary,
                ),
              ),
              const StreakRewardsStrip(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyGoalSection extends ConsumerWidget {
  const _DailyGoalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(dailyMissionsControllerProvider);

    // With no goals there is nothing to show, so the section is left out
    // (an empty card with a dead button looks broken).
    return missionsAsync.when(
      loading: () => const _SectionGap(
        child: _DashboardLoadingCard(label: 'Loading daily goals'),
      ),
      error: (error, stackTrace) => const _SectionGap(
        child: _DashboardMessageCard(message: 'Could not load today\'s goals.'),
      ),
      data: (missions) {
        if (missions.isEmpty) return const SizedBox.shrink();
        final completed = missions
            .where((mission) => mission.isCompleted)
            .length;
        final total = missions.length;
        final progress = total == 0 ? 0.0 : completed / total;
        final readyToCollect = missions
            .where((mission) => mission.canClaim)
            .length;
        final allCollected = missions.every((mission) => mission.claimed);
        final footerText = readyToCollect > 0
            ? (readyToCollect == 1
                  ? '1 reward ready to collect'
                  : '$readyToCollect rewards ready to collect')
            : allCollected
            ? 'All rewards collected. New goals tomorrow!'
            : 'Finish goals to earn coins and gems';

        return _SectionGap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                title: 'Today\'s goal',
                trailing: Text(
                  '$completed of $total',
                  style: context.appTextStyles.labelSmall.copyWith(
                    color: context.themeColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                      ),
                      child: AppProgressBar(
                        value: progress,
                        height: 6,
                        semanticLabel: 'Today\'s goal progress',
                      ),
                    ),
                    for (final mission in missions)
                      _DailyMissionRow(mission: mission),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.ms,
                      ),
                      decoration: BoxDecoration(
                        color: context.themeColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(
                            AppDimensions.borderRadiusCard,
                          ),
                        ),
                      ),
                      child: Text(
                        footerText,
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.labelLarge.copyWith(
                          color: context.themeColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyMissionRow extends ConsumerStatefulWidget {
  final DailyMission mission;

  const _DailyMissionRow({required this.mission});

  @override
  ConsumerState<_DailyMissionRow> createState() => _DailyMissionRowState();
}

class _DailyMissionRowState extends ConsumerState<_DailyMissionRow> {
  bool _collecting = false;

  Future<void> _collect() async {
    if (_collecting) return;
    final mission = widget.mission;
    setState(() => _collecting = true);
    final problem = await ref
        .read(dailyMissionsControllerProvider.notifier)
        .claim(mission.id);
    if (!mounted) return;
    setState(() => _collecting = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(problem ?? '${mission.rewardLabel} collected!')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final colors = context.themeColors;
    final isCompleted = mission.isCompleted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? colors.warning.withValues(alpha: 0.14)
                  : Colors.transparent,
              border: Border.all(
                color: isCompleted
                    ? colors.warning.withValues(alpha: 0.45)
                    : colors.borderStrong,
              ),
            ),
            child: isCompleted
                ? Icon(Icons.check, color: colors.warning, size: 16)
                : null,
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  softWrap: true,
                  style: context.appTextStyles.bodyLarge.copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: colors.textSecondary,
                    color: isCompleted
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
                if (!isCompleted)
                  Text(
                    '${mission.progressCount} of ${mission.targetCount}',
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (mission.canClaim)
            AppPressable(
              key: Key('collect_goal_${mission.id}'),
              onTap: _collecting ? null : _collect,
              borderRadius: AppDimensions.radiusCircular,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: AppDimensions.radiusCircular,
                ),
                child: _collecting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Collect ${mission.rewardLabel}',
                        style: context.appTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            )
          else
            Text(
              mission.claimed ? 'Collected' : mission.rewardLabel,
              style: context.appTextStyles.labelSmall.copyWith(
                color: mission.claimed ? colors.success : colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectsSection extends ConsumerWidget {
  final AsyncValue<List<LearningPath>> pathsAsync;
  final String? selectedPathId;

  const _SubjectsSection({
    required this.pathsAsync,
    required this.selectedPathId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenPadding(
          child: _SectionHeader(
            title: 'Your subjects',
            trailing: TextButton(
              onPressed: () => context.go(RouteNames.learningPath),
              child: const Text('See all'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        pathsAsync.when(
          loading: () => const _ScreenPadding(
            child: _DashboardLoadingCard(label: 'Loading subjects'),
          ),
          error: (error, stackTrace) => const _ScreenPadding(
            child: _DashboardMessageCard(message: 'Could not load subjects.'),
          ),
          data: (paths) {
            if (paths.isEmpty) {
              return const _ScreenPadding(
                child: _DashboardMessageCard(message: 'No subjects yet.'),
              );
            }

            // The row runs to both screen edges, so a card cut off at the
            // edge clearly says "scroll for more"; the first card still lines
            // up with the rest of the screen.
            return SizedBox(
              height: 176 * scale,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.horizontalScreen,
                itemCount: paths.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final path = paths[index];
                  final accent = _subjectAccentColor(context, index);
                  return _SubjectProgressCard(
                    path: path,
                    accent: accent,
                    isSelected: path.id == selectedPathId,
                    onTap: () => context.push(RouteNames.subjectPath(path.id)),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SubjectProgressCard extends StatelessWidget {
  final LearningPath path;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectProgressCard({
    required this.path,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    const progress = 0.0;

    return SizedBox(
      width: 255,
      child: AppPressable(
        onTap: onTap,
        borderRadius: AppDimensions.radiusCard,
        child: AppCard(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    // Room for two lines whatever the title, so every card
                    // lines up the same way.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: _titleBlockHeight(context),
                      ),
                      child: Text(
                        path.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: context.appTextStyles.titleMedium,
                      ),
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.my_location : Icons.folder_copy_outlined,
                    color: accent,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${path.topicCount} ${path.topicCount == 1 ? 'topic' : 'topics'}',
                style: context.appTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.ms),
              Row(
                children: [
                  Expanded(
                    child: AppProgressBar(
                      value: progress,
                      accentColor: accent,
                      height: 5,
                      semanticLabel: '${path.title} progress',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${(progress * 100).round()}%',
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AppBadge(
                label: _difficultyLabel(path.difficulty),
                variant: AppBadgeVariant.subjectAccent,
                accentColor: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _titleBlockHeight(BuildContext context) {
    final style = context.appTextStyles.titleMedium;
    final lineHeight = (style.fontSize ?? 18) * (style.height ?? 1.3);
    return MediaQuery.textScalerOf(context).scale(lineHeight) * 2;
  }

  String _difficultyLabel(LearningPathDifficulty difficulty) {
    return switch (difficulty) {
      LearningPathDifficulty.beginner => 'Beginner',
      LearningPathDifficulty.intermediate => 'Growing',
      LearningPathDifficulty.advanced => 'Advanced',
    };
  }
}

class _QuickPracticeSection extends ConsumerWidget {
  final String? selectedPathId;

  const _QuickPracticeSection({required this.selectedPathId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Quick practice'),
        const SizedBox(height: AppSpacing.sm),
        _QuickPracticeCards(selectedPathId: selectedPathId),
      ],
    );
  }
}

class _QuickPracticeCards extends ConsumerWidget {
  final String? selectedPathId;

  const _QuickPracticeCards({required this.selectedPathId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedPathId == null) {
      // Nothing chosen yet: the cards lead to choosing a subject instead of
      // sitting there looking switched off.
      void pick() => context.go(RouteNames.learningPath);
      return _QuickPracticeRow(onQuiz: pick, onSuddenDeath: pick);
    }

    final chaptersAsync = ref.watch(chaptersProvider(selectedPathId!));
    return chaptersAsync.when(
      loading: () => const _QuickPracticeRow(),
      error: (error, stackTrace) => const _DashboardMessageCard(
        message: 'Quick practice is unavailable.',
      ),
      data: (chapters) {
        final chapter = chapters.isEmpty ? null : chapters.first;
        if (chapter == null) {
          return const _DashboardMessageCard(
            message: 'No practice topics available.',
          );
        }

        final topicsAsync = ref.watch(topicsProvider(chapter.id));
        return topicsAsync.when(
          loading: () => const _QuickPracticeRow(),
          error: (error, stackTrace) => const _DashboardMessageCard(
            message: 'Quick practice is unavailable.',
          ),
          data: (topics) {
            final topic =
                _firstIncompleteTopic(topics) ??
                (topics.isEmpty ? null : topics.first);
            return _QuickPracticeRow(
              onQuiz: topic == null
                  ? null
                  : () => context.push(
                      RouteNames.subjectPlayPath(selectedPathId!),
                    ),
              // Like the quiz card, it opens the Play screen (with Sudden Death
              // already chosen) instead of jumping straight into a game.
              onSuddenDeath: topic == null
                  ? null
                  : () => context.push(
                      RouteNames.playSetupPath(
                        subjectId: selectedPathId,
                        quizType: QuestionType.suddenDeath,
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

class _QuickPracticeRow extends StatelessWidget {
  final VoidCallback? onQuiz;
  final VoidCallback? onSuddenDeath;

  const _QuickPracticeRow({this.onQuiz, this.onSuddenDeath});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickPracticeCard(
              icon: Icons.quiz_rounded,
              title: 'Quick quiz',
              subtitle: '10 questions',
              accent: colors.primary,
              onTap: onQuiz,
            ),
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: _QuickPracticeCard(
              icon: Icons.bolt_rounded,
              title: 'Sudden death',
              subtitle: 'Beat the clock',
              accent: AppColors.streakFire,
              onTap: onSuddenDeath,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPracticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  const _QuickPracticeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final enabled = onTap != null;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.ms),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.labelLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daily reward and the shortcuts to the spin wheel, chests and shop, under
/// one heading.
class _RewardsSection extends StatelessWidget {
  const _RewardsSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'Rewards'),
        SizedBox(height: AppSpacing.sm),
        _DailyRewardCard(),
        _RewardShortcuts(),
      ],
    );
  }
}

class _DailyRewardCard extends ConsumerWidget {
  const _DailyRewardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardAsync = ref.watch(dailyRewardControllerProvider);
    final colors = context.themeColors;

    // No reward today (or it is still loading): nothing to show.
    final reward = rewardAsync.valueOrNull;
    if (reward == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppPressable(
        onTap: reward.claimedToday
            ? null
            : () {
                ref.read(dailyRewardControllerProvider.notifier).claim();
                HapticFeedback.mediumImpact();
              },
        borderRadius: AppDimensions.radiusCard,
        child: AppCard(
          padding: AppSpacing.paddingMd,
          variant: AppCardVariant.tinted,
          tintColor: colors.warning,
          child: Row(
            children: [
              Icon(
                reward.claimedToday ? Icons.check_circle : Icons.card_giftcard,
                color: reward.claimedToday ? colors.success : colors.warning,
              ),
              const SizedBox(width: AppSpacing.ms),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.claimedToday ? 'Claimed' : '+${reward.coins}',
                      style: context.appTextStyles.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Daily reward',
                      style: context.appTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry points to the spin wheel, chests and shop. A small dot marks what is
/// waiting (today's free spin, a chest ready to open).
class _RewardShortcuts extends ConsumerWidget {
  const _RewardShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    final canSpin = rewards.canSpinOn(
      dateKey(ref.read(rewardsClockProvider)()),
    );
    final colors = context.themeColors;

    return Row(
      children: [
        Expanded(
          child: _RewardShortcut(
            icon: Icons.casino_rounded,
            label: 'Spin',
            color: AppColors.streakFire,
            showDot: canSpin,
            onTap: () => context.push(RouteNames.spinWheel),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _RewardShortcut(
            icon: Icons.inventory_2_rounded,
            label: 'Chests',
            color: colors.warning,
            showDot: rewards.anyChestReady,
            onTap: () => context.push(RouteNames.chest),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _RewardShortcut(
            icon: Icons.storefront_rounded,
            label: 'Shop',
            color: colors.primary,
            onTap: () => context.push(RouteNames.shop),
          ),
        ),
      ],
    );
  }
}

class _RewardShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool showDot;
  final VoidCallback onTap;

  const _RewardShortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.ms,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (showDot)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(label, style: context.appTextStyles.labelLarge),
          ],
        ),
      ),
    );
  }
}

/// The side gutter of the screen. The page list itself has none, so a row can
/// run to the screen edge.
class _ScreenPadding extends StatelessWidget {
  final Widget child;

  const _ScreenPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: AppSpacing.horizontalScreen, child: child);
  }
}

/// Space below a section that may be left out: it goes with the section, so
/// nothing is left over when the section is hidden.
class _SectionGap extends StatelessWidget {
  final Widget child;

  const _SectionGap({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.appTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Shown when no learning path has been chosen yet: one clear next step
/// instead of an empty message.
class _ChoosePathCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ChoosePathCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return AppPressable(
      key: const Key('choose_path_card'),
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: AppSpacing.paddingMd,
        variant: AppCardVariant.tinted,
        tintColor: colors.primary,
        child: Row(
          children: [
            Icon(Icons.explore_rounded, color: colors.primary, size: 30),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick your first subject',
                    style: context.appTextStyles.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose a learning path to unlock goals and practice.',
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingCard extends StatelessWidget {
  final String label;

  const _DashboardLoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: context.appTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _DashboardMessageCard extends StatelessWidget {
  final String message;

  const _DashboardMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(message, style: context.appTextStyles.bodyMedium),
    );
  }
}

Topic? _firstIncompleteTopic(List<Topic> topics) {
  for (final topic in topics) {
    if (!topic.isCompleted) return topic;
  }
  return null;
}

Color _subjectAccentColor(BuildContext context, int index) {
  final colors = context.themeColors;
  final accents = [
    colors.subjectAccountancy,
    colors.subjectBusinessStudies,
    colors.subjectEconomics,
  ];
  return accents[index % accents.length];
}
