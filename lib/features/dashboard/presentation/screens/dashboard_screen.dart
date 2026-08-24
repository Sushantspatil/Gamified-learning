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
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../chapters/domain/entities/topic.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../../daily_missions/domain/entities/daily_mission.dart';
import '../../../daily_missions/presentation/providers/daily_mission_providers.dart';
import '../../../daily_rewards/presentation/providers/daily_reward_providers.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../profile/presentation/avatar_catalog.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../streaks/domain/entities/streak.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';

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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.xl,
          ),
          children: [
            _ProfileHeader(
              displayName: user?.displayName ?? 'Learner',
              avatarId: profile?.avatarId ?? 'default',
              level: profile?.level ?? 1,
              streak: streakAsync.valueOrNull?.currentStreak ?? 0,
              gems: wallet?.gems ?? 0,
              onTap: () => context.push(RouteNames.profile),
            ),
            const SizedBox(height: AppSpacing.md),
            _SelectedPathDashboardSections(
              selectedPathId: selectedPathId,
              pathsAsync: pathsAsync,
            ),
            const SizedBox(height: AppSpacing.lg),
            _StreakSection(streakAsync: streakAsync),
            const SizedBox(height: AppSpacing.lg),
            const _DailyGoalSection(),
            const SizedBox(height: AppSpacing.lg),
            _SubjectsSection(
              pathsAsync: pathsAsync,
              selectedPathId: selectedPathId,
            ),
            const SizedBox(height: AppSpacing.lg),
            _QuickPracticeSection(selectedPathId: selectedPathId),
            const SizedBox(height: AppSpacing.lg),
            const _DailyRewardCard(),
          ],
        ),
      ),
      bottomNavigationBar: const _DashboardBottomNavigation(),
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
          return const _DashboardMessageCard(
            message: 'No learning path selected.',
          );
        }

        final chaptersAsync = ref.watch(chaptersProvider(selectedPathId!));

        return chaptersAsync.when(
          loading: () => _ContinueLearningCard(
            title: path.title,
            subtitle: path.description,
            completedTopics: 0,
            totalTopics: path.topicCount,
            onTap: () => context.push(RouteNames.learningPath),
          ),
          error: (error, stackTrace) => _ContinueLearningCard(
            title: path.title,
            subtitle: path.description,
            completedTopics: 0,
            totalTopics: path.topicCount,
            onTap: () => context.push(RouteNames.learningPath),
          ),
          data: (chapters) {
            final chapter = chapters.isEmpty ? null : chapters.first;
            if (chapter == null) {
              return _ContinueLearningCard(
                title: path.title,
                subtitle: path.description,
                completedTopics: 0,
                totalTopics: path.topicCount,
                onTap: () => context.push(RouteNames.learningPath),
              );
            }

            return _ContinueLearningCard(
              title: path.title,
              subtitle: chapter.title,
              completedTopics: 0,
              totalTopics: chapter.topicCount,
              onTap: () => context.push(RouteNames.chapterPath(chapter.id)),
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
  final int level;
  final int streak;
  final int gems;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.displayName,
    required this.avatarId,
    required this.level,
    required this.streak,
    required this.gems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Row(
      children: [
        Expanded(
          child: AppPressable(
            key: const Key('compact_profile_header'),
            onTap: onTap,
            borderRadius: AppDimensions.radiusMd,
            child: Row(
              children: [
                AppAvatar(
                  fallbackIcon: AvatarCatalog.iconFor(avatarId),
                  size: AppDimensions.avatarSizeMd,
                ),
                const SizedBox(width: AppSpacing.sm),
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
                        label: 'Level $level learner',
                        variant: AppBadgeVariant.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _MetricPill(
          icon: Icons.local_fire_department,
          iconColor: AppColors.streakFire,
          value: streak,
          semanticLabel: 'Current streak',
          tooltip: 'Leaderboard',
          onTap: () => context.push(RouteNames.leaderboard),
        ),
        const SizedBox(width: AppSpacing.sm),
        _MetricPill(
          icon: Icons.diamond,
          iconColor: AppColors.gemCyan,
          value: gems,
          semanticLabel: 'Gems',
          tooltip: 'Shop',
          onTap: () => context.push(RouteNames.shop),
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
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 17),
              const SizedBox(width: AppSpacing.xs),
              AnimatedCountText(
                value: value,
                style: context.appTextStyles.labelLarge,
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
        _SectionHeader(
          title: 'Your streak',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department,
                color: AppColors.streakFire,
                size: 16,
              ),
              Text(
                '$count day${count == 1 ? '' : 's'}',
                style: context.appTextStyles.labelSmall.copyWith(
                  color: context.themeColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var index = 0; index < 7; index++)
                    _StreakDayMarker(index: index, currentStreak: count),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Longest streak: $count day${count == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: context.appTextStyles.bodyMedium.copyWith(
                  color: context.themeColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakDayMarker extends StatelessWidget {
  final int index;
  final int currentStreak;

  const _StreakDayMarker({required this.index, required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final weekdayIndex = DateTime.now().weekday - 1;
    final daysFromToday = weekdayIndex - index;
    final isToday = index == weekdayIndex;
    final isCompleted = daysFromToday >= 0 && daysFromToday < currentStreak;
    final labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final accent = colors.warning;
    final borderColor = isToday
        ? accent
        : isCompleted
        ? accent.withValues(alpha: 0.45)
        : colors.borderStrong;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? accent.withValues(alpha: 0.12)
                : colors.surfaceElevated,
            border: Border.all(color: borderColor, width: isToday ? 2 : 1),
          ),
          child: isCompleted
              ? Icon(Icons.check, color: colors.warning, size: 17)
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          labels[index],
          style: context.appTextStyles.labelSmall.copyWith(
            color: isToday ? colors.textPrimary : colors.textMuted,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
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

    return missionsAsync.when(
      loading: () => const _DashboardLoadingCard(label: 'Loading daily goals'),
      error: (error, stackTrace) => const _DashboardMessageCard(
        message: 'Could not load today\'s goals.',
      ),
      data: (missions) {
        final completed = missions
            .where((mission) => mission.isCompleted)
            .length;
        final total = missions.length;
        final progress = total == 0 ? 0.0 : completed / total;
        final totalReward = missions.fold<int>(
          0,
          (sum, mission) => sum + mission.coinReward,
        );

        return Column(
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
            const SizedBox(height: AppSpacing.xs),
            AppProgressBar(
              value: progress,
              height: 4,
              semanticLabel: 'Today\'s goal progress',
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (missions.isEmpty)
                    Padding(
                      padding: AppSpacing.paddingMd,
                      child: Text(
                        'No goals available today.',
                        style: context.appTextStyles.bodyMedium,
                      ),
                    )
                  else
                    for (final mission in missions)
                      _DailyMissionRow(mission: mission),
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
                        bottom: Radius.circular(AppDimensions.borderRadiusCard),
                      ),
                    ),
                    child: Text(
                      totalReward == 0
                          ? 'Complete all goals'
                          : 'Complete all goals +$totalReward coins',
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
        );
      },
    );
  }
}

class _DailyMissionRow extends StatelessWidget {
  final DailyMission mission;

  const _DailyMissionRow({required this.mission});

  @override
  Widget build(BuildContext context) {
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
            child: Text(
              mission.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.bodyLarge.copyWith(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: colors.textSecondary,
                color: isCompleted ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '+${mission.coinReward} coins',
            style: context.appTextStyles.labelSmall.copyWith(
              color: colors.primary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Your subjects',
          trailing: TextButton(
            onPressed: () => context.push(RouteNames.learningPath),
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        pathsAsync.when(
          loading: () => const _DashboardLoadingCard(label: 'Loading subjects'),
          error: (error, stackTrace) =>
              const _DashboardMessageCard(message: 'Could not load subjects.'),
          data: (paths) {
            if (paths.isEmpty) {
              return const _DashboardMessageCard(message: 'No subjects yet.');
            }

            return SizedBox(
              height: 158,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
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
                    onTap: () => context.push(RouteNames.learningPath),
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
                children: [
                  Expanded(
                    child: Text(
                      path.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.titleMedium,
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.my_location : Icons.folder_copy_outlined,
                    color: accent,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${path.topicCount} topics',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick practice', style: context.appTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Strengthen today\'s concepts',
          style: context.appTextStyles.bodyMedium,
        ),
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
      return const _DisabledQuickPracticeCards();
    }

    final chaptersAsync = ref.watch(chaptersProvider(selectedPathId!));
    return chaptersAsync.when(
      loading: () => const _DisabledQuickPracticeCards(),
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
          loading: () => const _DisabledQuickPracticeCards(),
          error: (error, stackTrace) => const _DashboardMessageCard(
            message: 'Quick practice is unavailable.',
          ),
          data: (topics) {
            final topic =
                _firstIncompleteTopic(topics) ??
                (topics.isEmpty ? null : topics.first);
            return Row(
              children: [
                Expanded(
                  child: _QuickPracticeCard(
                    icon: Icons.quiz_outlined,
                    title: '10 question\nquiz',
                    onTap: topic == null
                        ? null
                        : () => context.push(RouteNames.quizPath(topic.id)),
                  ),
                ),
                const SizedBox(width: AppSpacing.ms),
                const Expanded(
                  child: _QuickPracticeCard(
                    icon: Icons.bolt,
                    title: 'Sudden\ndeath',
                    onTap: null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DisabledQuickPracticeCards extends StatelessWidget {
  const _DisabledQuickPracticeCards();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _QuickPracticeCard(
            icon: Icons.quiz_outlined,
            title: '10 question\nquiz',
            onTap: null,
          ),
        ),
        SizedBox(width: AppSpacing.ms),
        Expanded(
          child: _QuickPracticeCard(
            icon: Icons.bolt,
            title: 'Sudden\ndeath',
            onTap: null,
          ),
        ),
      ],
    );
  }
}

class _QuickPracticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _QuickPracticeCard({
    required this.icon,
    required this.title,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const SizedBox(height: AppSpacing.ms),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.appTextStyles.labelLarge.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyRewardCard extends ConsumerWidget {
  const _DailyRewardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardAsync = ref.watch(dailyRewardControllerProvider);
    final colors = context.themeColors;

    return rewardAsync.when(
      loading: () => const _DashboardLoadingCard(label: 'Loading daily reward'),
      error: (error, stackTrace) =>
          const _DashboardMessageCard(message: 'Could not load daily reward.'),
      data: (reward) {
        if (reward == null) {
          return const _DashboardMessageCard(
            message: 'No daily reward available.',
          );
        }

        return AppPressable(
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
                  reward.claimedToday
                      ? Icons.check_circle
                      : Icons.card_giftcard,
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
        );
      },
    );
  }
}

class _DashboardBottomNavigation extends ConsumerWidget {
  const _DashboardBottomNavigation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPathId = ref
        .watch(selectedLearningPathControllerProvider)
        .valueOrNull;

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: context.themeColors.surface,
          border: Border(top: BorderSide(color: context.themeColors.border)),
          boxShadow: AppElevation.shadows(context.themeColors, 1),
        ),
        child: Row(
          children: [
            _BottomNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: true,
              onTap: () => context.go(RouteNames.dashboard),
            ),
            _BottomNavItem(
              icon: Icons.menu_book_outlined,
              label: 'Learn',
              onTap: () => context.go(RouteNames.learningPath),
            ),
            _PlayNavItem(
              onTap: () => _openPractice(context, ref, selectedPathId),
            ),
            _BottomNavItem(
              icon: Icons.leaderboard_outlined,
              label: 'Rank',
              onTap: () => context.go(RouteNames.leaderboard),
            ),
            _BottomNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () => context.go(RouteNames.profile),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPractice(
    BuildContext context,
    WidgetRef ref,
    String? selectedPathId,
  ) async {
    if (selectedPathId == null) {
      context.go(RouteNames.learningPath);
      return;
    }

    final chapters = await ref.read(chaptersProvider(selectedPathId).future);
    if (!context.mounted || chapters.isEmpty) return;

    final chapterId = chapters.first.id;
    final topics = await ref.read(topicsProvider(chapterId).future);
    if (!context.mounted) return;

    if (topics.isEmpty) {
      context.go(RouteNames.chapterPath(chapterId));
      return;
    }

    final topic = _firstIncompleteTopic(topics) ?? topics.first;
    context.go(RouteNames.quizPath(topic.id));
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final color = isActive ? colors.primary : colors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Expanded(
      child: Center(
        child: AppPressable(
          onTap: onTap,
          borderRadius: AppDimensions.radiusCircular,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.violet],
              ),
              boxShadow: AppElevation.shadows(colors, 2),
            ),
            child: Icon(
              Icons.sports_esports,
              color: colors.primaryForeground,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: context.appTextStyles.titleLarge)),
        trailing,
      ],
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
